import argparse
from collections.abc import Iterator
import pickle
from typing import Any, Optional

import uvicorn
from fastapi import FastAPI, HTTPException
from pydantic import BaseModel

from wlo_topic_assistant._version import __version__
from wlo_topic_assistant.topic_assistant import TopicAssistant
from wlo_topic_assistant.topic_assistant2 import TopicAssistant2

app = FastAPI()


class Data(BaseModel):
    text: str


class Topic(BaseModel):
    weight: float
    uri: str
    label: Optional[str] = None
    match: Optional[str] = None


class Result(BaseModel):
    topics: list[Topic]
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

    # import topic assistents, if they have been cached
    def pre_loaded(cls: type):
        try:
            with open(f"data/{cls.__name__}_{__version__}.pkl", "rb") as f:
                return pickle.load(f)
        except FileNotFoundError:
            return cls()

    a = pre_loaded(TopicAssistant)
    a2 = pre_loaded(TopicAssistant2)

    @app.post("/topics")
    def topics(data: Data):
        output = a.go(data.text)
        return output

    @app.post("/topics2")
    def topics2(data: Data):
        output = a2.go(data.text)
        return output

    def __data_leaves(dictionary: dict) -> Iterator[tuple[list[str | int], Any]]:
        """Iterate over all leaf-nodes of a nested dictionary"""
        for key, value in dictionary.items():
            if type(value) is dict:
                if key == "data":
                    yield [key], value
                    continue

                for sub_keys, sub_value in __data_leaves(value):
                    yield [key] + sub_keys, sub_value

            elif type(value) is list:
                for index, entry in enumerate(value):
                    if type(entry) is dict:
                        for sub_keys, sub_value in __data_leaves(entry):
                            yield [key, index] + sub_keys, sub_value

    def __flatten_tree(tree: dict) -> list[Topic]:
        leaves = list()
        for _, data_leaf in __data_leaves(tree):
            leaves.append(
                Topic(
                    weight=data_leaf.get("w"),
                    uri=data_leaf.get("uri"),
                    label=data_leaf.get("label"),
                    match=data_leaf.get("match"),
                )
            )

        return leaves

    summary = "Predict topics from the OpenEduHub topic tree, using keywords"

    @app.post(
        "/topics_flat",
        summary=summary,
        description=f"""
        {summary}

        Parameters
        ----------
        text : str
            The text to be analyzed.

        Returns
        -------
        topics : list of Topic
            The predicted topics from the topic tree.
            Contains the following attributes:
        
            weight : int
                The number of matches in the sub tree.
            uri : str
                The URI of the topic.
            label : str, optional
                The label of the topic.
            match : str, optional
                The keyword in the text that was associated with the topic.
                If there are multiple, comma separated.
        version : str
            The version of the topic prediction tool.
        """,
    )
    def topics_flat(data: Data) -> Result:
        tree = a.go(data.text)
        return Result(topics=__flatten_tree(tree))

    summary = "Predict topics from the OpenEduHub topic tree, using word embeddings"

    @app.post(
        "/topics2_flat",
        summary=summary,
        description=f"""
        {summary}

        Parameters
        ----------
        text : str
            The text to be analyzed.

        Returns
        -------
        topics : list of Topic
            The predicted topics from the topic tree.
            Contains the following attributes:
        
            weight : int
                The weight attributed to the sub tree.
            uri : str
                The URI of the topic.
            label : str, optional
                The label of the topic.
            match : null
                Irrelevant for this function.
        version : str
            The version of the topic prediction tool.
        """,
    )
    def topics2_flat(data: Data) -> Result:
        tree = a2.go(data.text)
        return Result(topics=__flatten_tree(tree))

    uvicorn.run(
        "wlo_topic_assistant.webservice:app",
        host=args.host,
        port=args.port,
        reload=False,
    )


if __name__ == "__main__":
    main()
