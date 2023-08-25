#!/usr/bin/env python3
from setuptools import setup
from src.wlo_topic_assistant._version import __version__

setup(
    name="wlo-topic-assistant",
    version="0.1.2",
    description="A utility to map arbitrary text to the WLO/OEH topics vocabulary based on keyword matching.",
    author="",
    author_email="",
    packages=["wlo_topic_assistant"],
    install_requires=[
        d for d in open("requirements.txt").readlines() if not d.startswith("--")
    ],
    package_dir={"": "src"},
    entry_points={
        "console_scripts": [
            "wlo-topic-assistant = wlo_topic_assistant.webservice:main",
            "preload = wlo_topic_assistant.generate_assistants:main",
        ]
    },
)
