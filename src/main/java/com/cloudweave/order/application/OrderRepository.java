package com.cloudweave.order.application;

import com.cloudweave.order.domain.Order;
import java.util.Optional;

public interface OrderRepository {
    Order save(Order order);
    Optional<Order> findById(String orderId);
}
