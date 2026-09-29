package com.cloudweave.order.infrastructure.persistence;

import com.cloudweave.order.domain.OrderStatus;
import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.EnumType;
import jakarta.persistence.Enumerated;
import jakarta.persistence.Id;
import jakarta.persistence.Table;

import java.math.BigDecimal;

@Entity
@Table(name = "orders")
class OrderEntity {
    @Id
    @Column(name = "order_id", nullable = false, updatable = false, length = 36)
    private String orderId;
    @Column(name = "total_amount", nullable = false, precision = 19, scale = 2)
    private BigDecimal totalAmount;
    @Column(nullable = false, length = 3)
    private String currency;
    @Enumerated(EnumType.STRING)
    @Column(nullable = false, length = 20)
    private OrderStatus status;

    protected OrderEntity() {}

    OrderEntity(String orderId, BigDecimal totalAmount, String currency, OrderStatus status) {
        this.orderId = orderId;
        this.totalAmount = totalAmount;
        this.currency = currency;
        this.status = status;
    }

    String getOrderId() { return orderId; }
    BigDecimal getTotalAmount() { return totalAmount; }
    String getCurrency() { return currency; }
    OrderStatus getStatus() { return status; }
}
