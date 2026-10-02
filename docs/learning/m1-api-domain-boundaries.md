# M1 Learning Notes：API、Domain 與 Error Boundary

**Milestone：M1 — Order Service**

這份文件記錄 M1 實作後，幾個容易忽略、但會直接影響未來 Cloud workload 演進的重要設計觀念。

---

## 1. API Request／Response 與 Domain Entity 分離

外部 API contract 與內部 Domain model 是兩個不同的 boundary。

目前 Create Order 使用：

- `CreateOrderRequest`：描述 Client 可以提供的 input。
- `OrderResponse`：描述 API 對外承諾的 output。
- `Order`：維護內部 business state 與 invariants。

Controller 先把 JSON 轉成 `CreateOrderRequest`，再把需要的值交給 `OrderService`。Application 完成操作後，Controller 透過 `OrderResponse.from(order)` 將 Domain Entity 轉成 response DTO。

因此 `Order` 不會被直接當成 HTTP request 或 response 使用。

這個分離的價值是：

- 外部 API 欄位演進時，不必直接改動 Domain model。
- Domain model 增加內部資料時，不會自動暴露給 Client。
- Client 無法藉由 JSON binding 修改不應由外部控制的 state。
- API version 與 Domain evolution 可以用不同速度前進。

相關程式：

- `src/main/java/com/cloudweave/order/web/CreateOrderRequest.java`
- `src/main/java/com/cloudweave/order/web/OrderResponse.java`
- `src/main/java/com/cloudweave/order/domain/Order.java`

---

## 2. Client 不能直接指定 Order status

Create Order 的 request 只有：

```json
{
  "totalAmount": 125.50,
  "currency": "TWD"
}
```

它沒有 `orderId` 或 `status`。

- `orderId` 由 `OrderService.createOrder()` 產生。
- initial state 由 `Order` constructor 固定為 `CREATED`。

這表示 Client 只能提出「建立訂單」的請求，不能自行建立一筆已經 `CONFIRMED` 或 `CANCELLED` 的 Order。

Order status 是 business state，不只是可以自由修改的資料欄位。所有 status change 都必須經過 Domain 提供的 operation 與 transition rule。

---

## 3. Confirm／Cancel 是明確的 Business Operations

目前 API 使用：

```text
POST /api/v1/orders/{orderId}/confirm
POST /api/v1/orders/{orderId}/cancel
```

它們分別對應：

```java
Order.confirm()
Order.cancel()
```

不應提供這種共通資料修改 API：

```http
PATCH /orders/{orderId}
Content-Type: application/json

{
  "status": "CONFIRMED"
}
```

`PATCH status` 讓 Client 看起來像是在直接指定資料的新值；`confirm` 則表達 Client 要求 Order 執行一個有 business meaning 的 operation。

明確 operation 的優點：

- Domain 可以判斷目前 state 是否允許該 operation。
- API 能清楚表達 Client intent。
- 未來加入 audit、authorization、event 或 observability 時，有明確的 business action 可以追蹤。
- 不會把 business transition 降級成任意欄位更新。

目前合法 transition 只有：

```text
CREATED → CONFIRMED
CREATED → CANCELLED
```

`Order.requireCreated()` 會拒絕其他 transition，並丟出 `InvalidOrderStateException`。

---

## 4. `/api/v1` 是 External Contract 的 Version Boundary

目前 API path 使用：

```text
/api/v1/orders
```

`v1` 表示這是 external contract 的第一個版本，而不是 Java class 或 application release version。

如果未來出現不相容的 API change，可以提供：

```text
/api/v1/orders
/api/v2/orders
```

兩個版本可以暫時並存，讓既有 Client 有 migration window，而不是部署新版後立刻破壞所有舊 Client。

Versioning 不代表每次小修改都需要新增版本。新增 optional field 或不破壞既有行為的 change，通常仍可留在 v1；只有 incompatible contract change 才需要評估新版本。

---

## 5. HTTP Error Code 與內部 Exception 分離

Domain 與 Application 用 exception 表達內部 failure meaning：

- `InvalidOrderException`：Order business data 無效。
- `InvalidOrderStateException`：business transition 不合法。
- `OrderNotFoundException`：Application 找不到指定 Order。

這些 exception 不知道 HTTP status code。HTTP translation 只存在於 Web layer 的 `ApiExceptionHandler`：

| Internal failure | HTTP response |
|---|---:|
| malformed JSON | 400 |
| `OrderNotFoundException` | 404 |
| `InvalidOrderStateException` | 409 |
| validation／`InvalidOrderException` | 422 |
| unexpected `Exception` | 500 |

這個 boundary 讓 Domain 未來也能被 message consumer、batch job 或其他 adapter 使用，而不會帶著 HTTP-specific concern。

對於 unexpected failure，API 只回傳安全且穩定的訊息：

```text
Unexpected server error.
```

Response 不應暴露：

- Java exception class name
- stack trace
- SQL 或 persistence implementation
- database/table/column 資訊
- internal file path
- credentials 或 infrastructure details

詳細錯誤應留在未來的 internal logs 與 observability system，而不是交給 API Client。

---

## 6. `ApiExceptionHandler` 如何被使用

`OrderController` 不會直接呼叫 `ApiExceptionHandler`。

Spring Boot 啟動時掃描到：

```java
@RestControllerAdvice
public class ApiExceptionHandler {
}
```

`@RestControllerAdvice` 會把其中的 `@ExceptionHandler` methods 註冊成所有 REST Controllers 共用的 exception translation mechanism。

實際流程如下：

```text
HTTP Request
    ↓
OrderController
    ↓
OrderService
    ↓
Order Domain／Repository
    ↓ throws exception
Spring MVC catches the exception
    ↓ selects matching @ExceptionHandler
ApiExceptionHandler
    ↓
HTTP status + ApiError JSON
```

### 範例：查詢不存在的 Order

Request：

```http
GET /api/v1/orders/not-exist
```

1. `OrderController.getOrder()` 呼叫 `OrderService.getOrder("not-exist")`。
2. Repository 回傳 `Optional.empty()`。
3. `OrderService` 丟出 `OrderNotFoundException`。
4. Controller 沒有攔截，exception 繼續交給 Spring MVC。
5. Spring 找到處理 `OrderNotFoundException` 的 `handleNotFound()`。
6. `ApiExceptionHandler` 建立 `ApiError` 並回傳 HTTP 404。

```json
{
  "timestamp": "...",
  "status": 404,
  "error": "Not Found",
  "message": "Order not found: not-exist"
}
```

Spring 依照實際 exception type 選擇最符合的 handler。最後的：

```java
@ExceptionHandler(Exception.class)
```

是 fallback，只處理前面沒有更具體 handler 可以處理的 unexpected failure。

集中處理的結果是 Controller 不需要重複撰寫 `try/catch`，且所有 endpoints 能維持一致的 error response semantics。

相關程式：

- `src/main/java/com/cloudweave/order/web/ApiExceptionHandler.java`
- `src/main/java/com/cloudweave/order/web/ApiError.java`
- `src/main/java/com/cloudweave/order/application/OrderNotFoundException.java`
- `src/main/java/com/cloudweave/order/domain/InvalidOrderException.java`
- `src/main/java/com/cloudweave/order/domain/InvalidOrderStateException.java`

---

## M1 核心結論

Order Service 對外提供的不是一組任意 CRUD 欄位修改能力，而是一組受 business rules 保護的 operations。

```text
API contract
    ↓ translates input/output and errors
Application use case
    ↓ coordinates operation
Domain
    ↓ protects invariants and transitions
Repository abstraction
    ↓
Infrastructure implementation
```

這些 boundary 讓未來更換 persistence、部署到 Cloud、加入 events 或 observability 時，可以替換外圍 capability，而不需要推翻已 Freeze 的 Order business rules。
