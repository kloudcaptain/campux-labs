from mcp.server.fastmcp import FastMCP

# bind to all interfaces on 8080 so Container Apps ingress can reach it
mcp = FastMCP("campux-inventory", host="0.0.0.0", port=8080)

# stand-in for an enterprise system the AI is allowed to read
STOCK = {
    "Camden":     {"oat-milk": 42, "espresso-beans": 130, "napkins": 8},
    "Shoreditch": {"oat-milk": 5,  "espresso-beans": 76,  "napkins": 240},
}


@mcp.tool()
def get_inventory(store: str) -> str:
    """Return current stock levels for a Campux Retail store."""
    if store not in STOCK:
        return f"Unknown store '{store}'. Known: {', '.join(STOCK)}."
    lines = [f"{k}: {v}" for k, v in STOCK[store].items()]
    return f"Stock at {store} - " + "; ".join(lines)


if __name__ == "__main__":
    mcp.run(transport="streamable-http")
