#!/usr/bin/env python3
"""Inventory simulation with (r, Q) replenishment policy."""

import numpy as np


def simulate(horizon=100, stock=50, r=20, Q=60, lead=3,
             seed=42):
    rng = np.random.default_rng(seed)
    pending = []
    orders = 0
    for t in range(horizon):
        pending = [(rem - 1, q) for rem, q in pending]
        for _, qty in [(r, q) for r, q in pending if r <= 0]:
            stock += qty
        pending = [x for x in pending if x[0] > 0]
        demand = max(0.0, rng.normal(10.0, 3.0))
        stock -= min(stock, demand)
        if stock <= r and not pending:
            pending.append((lead, Q))
            orders += 1
    return stock, orders


if __name__ == "__main__":
    stock, orders = simulate(horizon=200, lead=5)
    print(f"Final stock: {stock:.0f}")
    print(f"Orders placed: {orders}")
