import asyncio, sys
from mcp import ClientSession
from mcp.client.streamable_http import streamablehttp_client


async def main(url):
    async with streamablehttp_client(url) as (read, write, _):
        async with ClientSession(read, write) as session:
            await session.initialize()
            tools = await session.list_tools()
            print("tools:", [t.name for t in tools.tools])
            out = await session.call_tool("get_inventory", {"store": "Camden"})
            print("result:", out.content[0].text)


asyncio.run(main(sys.argv[1]))
