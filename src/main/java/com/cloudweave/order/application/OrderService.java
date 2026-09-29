package com.cloudweave.order.application;

import com.cloudweave.order.domain.Order;
import org.springframework.stereotype.Service;

import java.math.BigDecimal;
import java.util.UUID;

@Service
public class OrderService {
    private final OrderRepository orderRepository;

    public OrderService(OrderRepository orderRepository) {
        this.orderRepository = orderRepository;
    }

    public Order createOrder(BigDecimal totalAmount, String currency) {
        Order order = Order.create(UUID.randomUUID().toString(), totalAmount, currency);
        return orderRepository.save(order);
    }

    public Order getOrder(String orderId) {
        return orderRepository.findById(orderId)
                .orElseThrow(() -> new OrderNotFoundException(orderId));
    }

    public Order confirmOrder(String orderId) {
        Order order = getOrder(orderId);
        order.confirm();
        return orderRepository.save(order);
    }

    public Order cancelOrder(String orderId) {
        Order order = getOrder(orderId);
        order.cancel();
        return orderRepository.save(order);
    }
}
