package com.cloudweave.order.infrastructure.persistence;

import com.cloudweave.order.application.OrderRepository;
import com.cloudweave.order.domain.Order;
import com.cloudweave.order.domain.OrderStatus;
import org.springframework.stereotype.Repository;

import java.util.Optional;

@Repository
public class PostgresOrderRepository implements OrderRepository {
    private final SpringDataOrderRepository repository;

    public PostgresOrderRepository(SpringDataOrderRepository repository) { this.repository = repository; }

    @Override
    public Order save(Order order) { return toDomain(repository.saveAndFlush(toEntity(order))); }

    @Override
    public Optional<Order> findById(String orderId) { return repository.findById(orderId).map(this::toDomain); }

    private OrderEntity toEntity(Order order) {
        return new OrderEntity(order.getOrderId(), order.getTotalAmount(), order.getCurrency(), order.getStatus());
    }

    private Order toDomain(OrderEntity entity) {
        Order order = Order.create(entity.getOrderId(), entity.getTotalAmount(), entity.getCurrency());
        if (entity.getStatus() == OrderStatus.CONFIRMED) order.confirm();
        else if (entity.getStatus() == OrderStatus.CANCELLED) order.cancel();
        return order;
    }
}
