import argparse
import pickle

from wlo_topic_assistant._version import __version__
from wlo_topic_assistant.topic_assistant import TopicAssistant
from wlo_topic_assistant.topic_assistant2 import TopicAssistant2


# import topic assistents, if they have been cached
def dump(cls: type, path: str):
    with open(f"{path}/{cls.__name__}_{__version__}.pkl", "wb+") as f:
        pickle.dump(cls(), f)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("path", type=str)

    args = parser.parse_args()
    dump(TopicAssistant, args.path)
    dump(TopicAssistant2, args.path)


if __name__ == "__main__":
    main()
