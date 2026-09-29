# M2 — PostgreSQL + Docker Walkthrough

M2 將 M1 的暫時性記憶體儲存替換成 PostgreSQL，同時維持既有 Domain Model、REST API 與錯誤語意。系統現在是：

```text
Client -> OrderController -> OrderService -> OrderRepository
                                              |
                                              v
                                  PostgresOrderRepository
                                              |
                                              v
                                  Spring Data JPA -> PostgreSQL
```

## 1. 重要檔案

```text
CloudWeave/
├── Dockerfile
├── compose.yaml
├── .dockerignore
├── .env.example
├── pom.xml
└── src/
    ├── main/
    │   ├── java/com/cloudweave/order/
    │   │   ├── application/
    │   │   │   ├── OrderRepository.java
    │   │   │   └── OrderService.java
    │   │   └── infrastructure/persistence/
    │   │       ├── OrderEntity.java
    │   │       ├── SpringDataOrderRepository.java
    │   │       └── PostgresOrderRepository.java
    │   └── resources/
    │       ├── application.properties
    │       └── db/migration/V1__create_orders_table.sql
    └── test/java/com/cloudweave/order/web/OrderApiTest.java
```

- `pom.xml`：加入 JPA、PostgreSQL driver、Flyway 與 Testcontainers。
- `application.properties`：從環境變數取得連線資訊；`ddl-auto=validate` 只驗證 schema，不讓 Hibernate 建表。
- `OrderEntity`：只負責資料表欄位 mapping，避免 JPA annotation 污染 Domain `Order`。
- `SpringDataOrderRepository`：提供 JPA 的 CRUD 實作。
- `PostgresOrderRepository`：實作既有 `OrderRepository`，並轉換 Domain 與 Entity。
- `V1__create_orders_table.sql`：orders schema 的第一個可追蹤版本。
- `Dockerfile`：建置及執行 Spring Boot image。
- `compose.yaml`：啟動 `order-service`、`postgres`、healthcheck 與 named volume。
- `.env.example`：可覆寫的本機設定範例；真正 `.env` 被 `.gitignore` 排除。
- `OrderApiTest`：使用 PostgreSQL 17 Testcontainer 驗證真正的 Flyway/JPA/API 路徑；未啟動 Docker 時會跳過。

## 2. 寫入與讀取流程

`POST /api/v1/orders`：

1. `OrderController` 驗證 JSON，呼叫 `OrderService.createOrder`。
2. `OrderService` 用 `Order.create` 建立 Domain object；規則仍由 Domain 保護。
3. Service 只認識 `OrderRepository` interface。
4. Spring 注入 `PostgresOrderRepository`；它把 `Order` 轉為 `OrderEntity`。
5. `SpringDataOrderRepository.saveAndFlush` 交給 JPA/Hibernate 產生 SQL。
6. PostgreSQL 寫入 `orders`，adapter 再將結果轉回 Domain object。

`GET /api/v1/orders/{orderId}` 走反方向：PostgreSQL row -> JPA entity -> adapter mapping -> Domain `Order` -> `OrderResponse` -> JSON。

## 3. Repository abstraction 的價值

M1 是 `OrderRepository -> InMemoryOrderRepository`；M2 是 `OrderRepository -> PostgresOrderRepository`。未修改 `OrderRepository`、Domain 的四個欄位與狀態規則、Controller 路徑及 response contract。`OrderService` 只有 confirm/cancel 增加 transaction boundary。

因此未來部署到 ECS/Fargate 時，application use case 不需要知道資料庫是本機 container 還是 RDS；改變的是 infrastructure 與 configuration，不是 business rule。

## 4. 這個專案需要的 JPA 概念

- Entity mapping：`OrderEntity` 將 Java 欄位對應 `orders` 欄位；它不是 Domain model。
- Repository：Spring Data 根據 `JpaRepository<OrderEntity, String>` 產生 CRUD implementation。
- Persistence boundary：只有 `infrastructure.persistence` 看見 JPA；application 只依賴自己的 interface。
- Transaction：confirm/cancel 是「讀取目前狀態、執行 transition、儲存」的一個工作單位，因此在 `OrderService` 使用 `@Transactional`。

## 5. Flyway

Flyway 解決 schema 如何被版本化、重現及安全升級的問題。應用啟動時，Spring Boot 在建立可用的 JPA EntityManagerFactory 前執行 Flyway；Flyway 讀取 `db/migration`，比較 `flyway_schema_history`，只執行尚未套用的版本。

`V1__create_orders_table.sql` 是 schema 的 source of truth。Hibernate 設為 `validate`，只確認 entity 與資料表相容；若 schema 不合，啟動失敗，而不是偷偷修改 production database。

## 6. Dockerfile 逐行

```dockerfile
FROM maven:3.9.11-eclipse-temurin-21 AS build
WORKDIR /workspace
COPY pom.xml .
RUN mvn -B dependency:go-offline
COPY src ./src
RUN mvn -B clean package -DskipTests

FROM eclipse-temurin:21-jre-alpine
WORKDIR /app
COPY --from=build /workspace/target/order-service-*.jar app.jar
EXPOSE 8080
ENTRYPOINT ["java", "-jar", "app.jar"]
```

- 第一個 `FROM` 是 build stage，含 Maven 與 Java 21 JDK。
- `WORKDIR` 設定後續命令的容器目錄。
- 先 copy `pom.xml` 並下載 dependency，讓 Docker layer cache 可重用。
- 再 copy source 並 package；tests 已在 host/Testcontainers 階段跑過。
- 第二個 `FROM` 是較小的 Java 21 JRE runtime stage，不帶 Maven/compiler/source。
- `COPY --from=build` 只帶入可執行 JAR。
- `EXPOSE 8080` 記錄 container listening port；真正 host mapping 在 Compose。
- `ENTRYPOINT` 定義 container 啟動命令。

Multi-stage build 把建置工具留在前一階段，使 runtime image 更小、攻擊面更少。

## 7. Docker Compose

- `service`：此專案有 `postgres` 與 `order-service` 兩個服務。
- `image/build`：PostgreSQL 使用官方 image；Order Service 從本地 Dockerfile build。
- `ports`：左邊是 host port，右邊是 container port，例如 `8080:8080`。
- `environment`：Compose 提供 datasource 設定；可由 `.env` 覆寫本機預設值。
- Docker network/DNS：Compose 建立 default network，service name 自動成為 DNS name。
- `depends_on`：等待 PostgreSQL healthcheck 成功後才啟動 application。
- `healthcheck`：用 `pg_isready` 判斷 DB 是否能接受連線。
- named volume：`postgres-data` 掛載到 PostgreSQL data directory，生命週期獨立於 container。

`localhost` 在 `order-service` container 中代表它自己，不是 PostgreSQL container。因此 JDBC URL 必須使用 `postgres:5432`；`postgres` 是 Compose DNS 可解析的 service name。

## 8. 資料持久化實驗

啟動並建立訂單：

```powershell
docker compose up -d --build
$order = Invoke-RestMethod -Method Post -Uri http://localhost:8080/api/v1/orders -ContentType application/json -Body '{"totalAmount":125.50,"currency":"TWD"}'
$order
```

重啟 application 後查詢：

```powershell
docker compose restart order-service
Invoke-RestMethod http://localhost:8080/api/v1/orders/$($order.orderId)
```

重啟 PostgreSQL 後再查詢：

```powershell
docker compose restart postgres
Invoke-RestMethod http://localhost:8080/api/v1/orders/$($order.orderId)
```

一般停止不刪 volume：`docker compose down`。刻意刪除資料做對照實驗：`docker compose down --volumes`。後者會永久刪除這個 Compose project 的 database volume；再次 up 時是空資料庫。named volume 重要之處是 container 可替換，而 data directory 仍保留。

## 9. 檢查 PostgreSQL

```powershell
docker compose exec postgres psql -U cloudweave -d cloudweave
```

進入 `psql` 後：

```sql
\dt
SELECT * FROM orders;
SELECT installed_rank, version, description, installed_on, success
FROM flyway_schema_history;
\q
```

## 10. Build、Run、Test

```powershell
mvn test
mvn clean package
docker build -t cloudweave-order-service .
docker compose up -d --build
docker compose down
docker compose ps
docker compose logs -f order-service
docker compose logs -f postgres
docker inspect cloudweave-order-service-1
```

本機 Maven 必須使用 Java 21。整合測試需要正在運行的 Docker；若 Docker 不可用，Testcontainers tests 會被標為 skipped。

## 11. BREAK exercise（先不要看答案）

在 `compose.yaml` 暫時把 `DB_URL` 中的 hostname 從 `postgres` 改成 `wrong-postgres`，再執行 `docker compose up -d --build`。

觀察：

```powershell
docker compose ps
docker compose logs -f order-service
docker compose logs postgres
```

記錄 application container 的狀態、第一個有意義的 exception、其中出現的 hostname，以及 PostgreSQL 是否仍 healthy。先用這些證據自行判斷問題位於 application、network/DNS 或 database；完成調查後把 hostname 改回 `postgres`。

## 12. 對未來 AWS M4 的連結

本機 `Order Service container -> PostgreSQL container`，未來概念上對應 `ECS/Fargate task -> RDS PostgreSQL`。會延續的概念是 container image、外部化設定、network address、credentials、health/readiness、migration、durable storage 與 failure isolation。

會改變的是 Compose DNS/port mapping 變成 VPC DNS、subnet、security group；本機帳密變成 Secrets Manager 等 secret delivery；named volume 的責任變成 RDS managed storage、backup、Multi-AZ 與 maintenance。M2 不實作這些 AWS 細節。

## 13. The 7 things I should understand before freezing M2

1. Container 是可替換的 process boundary，資料不應只存在 application memory 或 container writable layer。
2. Repository interface 讓 business/application logic 不依賴 PostgreSQL/JPA。
3. JPA entity 是 persistence model，不必等於 Domain model。
4. Flyway migration 是 database schema 的版本化 source of truth；Hibernate 在此只 validate。
5. Container 內的 `localhost` 是該 container；跨 service 要用 Docker DNS 的 service name。
6. `depends_on + healthcheck` 改善啟動順序，但 runtime database failure 仍必須從 logs/metrics 理解與處理。
7. Local Compose 到 ECS/RDS 的核心概念會延續，但 networking、secrets、availability 與 operations 會交給雲端服務與後續 milestone。

M2 到此停止，不開始 M3。
