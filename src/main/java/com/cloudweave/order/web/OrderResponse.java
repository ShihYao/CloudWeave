package com.cloudweave.order.web;

import com.cloudweave.order.domain.Order;
import com.cloudweave.order.domain.OrderStatus;

import java.math.BigDecimal;

public record OrderResponse(
        String orderId,
        BigDecimal totalAmount,
        String currency,
        OrderStatus status) {

    public static OrderResponse from(Order order) {
        return new OrderResponse(
                order.getOrderId(),
                order.getTotalAmount(),
                order.getCurrency(),
                order.getStatus());
    }
}
