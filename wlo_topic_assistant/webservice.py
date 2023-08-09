import argparse

import uvicorn
from fastapi import FastAPI, HTTPException
from pydantic import BaseModel

from wlo_topic_assistant.topic_assistant import TopicAssistant
from wlo_topic_assistant._version import __version__
from wlo_topic_assistant.topic_assistant2 import TopicAssistant2

app = FastAPI()


class Data(BaseModel):
    text: str


class Result(BaseModel):
    tree: dict
    version: str = __version__


@app.get("/_ping")
def _ping():
    pass


def main():
    # define CLI arguments
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--port", action="store", default=8080, help="Port to listen on", type=int
    )
    parser.add_argument(
        "--host", action="store", default="0.0.0.0", help="Hosts to listen to", type=str
    )
    parser.add_argument(
        "--version",
        action="version",
        version="%(prog)s {version}".format(version=__version__),
    )

    # read passed CLI arguments
    args = parser.parse_args()

    a = TopicAssistant()

    @app.post("/topics")
    def topics(data: Data) -> Result:
        output = a.go(data.text)
        return Result(tree=output)

    a2 = TopicAssistant2()

    @app.post("/topics2")
    def topics2(data: Data) -> Result:
        output = a2.go(data.text)
        return Result(tree=output)

    uvicorn.run(
        "wlo_topic_assistant.webservice:app",
        host=args.host,
        port=args.port,
        reload=False,
    )


if __name__ == "__main__":
    main()
