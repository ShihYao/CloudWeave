package com.cloudweave.order.domain;

import java.math.BigDecimal;
import java.util.Objects;

public final class Order {
    private final String orderId;
    private final BigDecimal totalAmount;
    private final String currency;
    private OrderStatus status;

    private Order(String orderId, BigDecimal totalAmount, String currency) {
        if (orderId == null || orderId.isBlank()) {
            throw new InvalidOrderException("Order ID is required.");
        }
        if (totalAmount == null || totalAmount.compareTo(BigDecimal.ZERO) <= 0) {
            throw new InvalidOrderException("Total amount must be greater than zero.");
        }
        if (currency == null || currency.isBlank()) {
            throw new InvalidOrderException("Currency is required.");
        }
        this.orderId = orderId;
        this.totalAmount = totalAmount;
        this.currency = currency;
        this.status = OrderStatus.CREATED;
    }

    public static Order create(String orderId, BigDecimal totalAmount, String currency) {
        return new Order(orderId, totalAmount, currency);
    }

    public void confirm() {
        requireCreated("confirmed");
        status = OrderStatus.CONFIRMED;
    }

    public void cancel() {
        requireCreated("cancelled");
        status = OrderStatus.CANCELLED;
    }

    private void requireCreated(String operation) {
        if (status != OrderStatus.CREATED) {
            throw new InvalidOrderStateException(
                    "Order cannot be %s from status %s.".formatted(operation, status));
        }
    }

    public String getOrderId() { return orderId; }
    public BigDecimal getTotalAmount() { return totalAmount; }
    public String getCurrency() { return currency; }
    public OrderStatus getStatus() { return status; }

    @Override
    public boolean equals(Object other) {
        if (this == other) return true;
        return other instanceof Order order && orderId.equals(order.orderId);
    }

    @Override
    public int hashCode() {
        return Objects.hash(orderId);
    }
}
