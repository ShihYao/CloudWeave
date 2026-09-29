package com.cloudweave.order.domain;

import org.junit.jupiter.api.Test;

import java.math.BigDecimal;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

class OrderTest {

    @Test
    void createsAnOrderInCreatedState() {
        Order order = Order.create("order-1", new BigDecimal("12.50"), "TWD");

        assertThat(order.getStatus()).isEqualTo(OrderStatus.CREATED);
    }

    @Test
    void rejectsNonPositiveAmount() {
        assertThatThrownBy(() -> Order.create("order-1", BigDecimal.ZERO, "TWD"))
                .isInstanceOf(InvalidOrderException.class);
    }

    @Test
    void rejectsBlankCurrency() {
        assertThatThrownBy(() -> Order.create("order-1", BigDecimal.TEN, " "))
                .isInstanceOf(InvalidOrderException.class);
    }

    @Test
    void confirmsCreatedOrder() {
        Order order = Order.create("order-1", BigDecimal.TEN, "TWD");

        order.confirm();

        assertThat(order.getStatus()).isEqualTo(OrderStatus.CONFIRMED);
    }

    @Test
    void cancelsCreatedOrder() {
        Order order = Order.create("order-1", BigDecimal.TEN, "TWD");

        order.cancel();

        assertThat(order.getStatus()).isEqualTo(OrderStatus.CANCELLED);
    }

    @Test
    void rejectsTransitionFromTerminalState() {
        Order order = Order.create("order-1", BigDecimal.TEN, "TWD");
        order.confirm();

        assertThatThrownBy(order::cancel)
                .isInstanceOf(InvalidOrderStateException.class);
    }
}
