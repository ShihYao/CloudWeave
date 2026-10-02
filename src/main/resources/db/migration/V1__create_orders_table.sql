CREATE TABLE orders (
    order_id VARCHAR(36) PRIMARY KEY,
    total_amount NUMERIC(19, 2) NOT NULL CHECK (total_amount > 0),
    currency VARCHAR(3) NOT NULL,
    status VARCHAR(20) NOT NULL CHECK (status IN ('CREATED', 'CONFIRMED', 'CANCELLED'))
);
