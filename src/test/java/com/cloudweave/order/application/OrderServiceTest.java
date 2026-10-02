package com.cloudweave.order.application;

import com.cloudweave.order.domain.Order;
import com.cloudweave.order.domain.OrderStatus;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;

import java.math.BigDecimal;
import java.util.HashMap;
import java.util.Map;
import java.util.Optional;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

class OrderServiceTest {
    private OrderService orderService;

    @BeforeEach
    void setUp() {
        orderService = new OrderService(new TestOrderRepository());
    }

    @Test
    void createsAndPersistsAnOrder() {
        Order order = orderService.createOrder(new BigDecimal("100.00"), "TWD");

        assertThat(order.getOrderId()).isNotBlank();
        assertThat(orderService.getOrder(order.getOrderId())).isEqualTo(order);
    }

    @Test
    void confirmsAnExistingOrder() {
        Order order = orderService.createOrder(BigDecimal.TEN, "USD");

        Order confirmed = orderService.confirmOrder(order.getOrderId());

        assertThat(confirmed.getStatus()).isEqualTo(OrderStatus.CONFIRMED);
    }

    @Test
    void reportsMissingOrder() {
        assertThatThrownBy(() -> orderService.getOrder("missing"))
                .isInstanceOf(OrderNotFoundException.class);
    }

    private static class TestOrderRepository implements OrderRepository {
        private final Map<String, Order> orders = new HashMap<>();

        @Override
        public Order save(Order order) {
            orders.put(order.getOrderId(), order);
            return order;
        }

        @Override
        public Optional<Order> findById(String orderId) {
            return Optional.ofNullable(orders.get(orderId));
        }
    }
}
