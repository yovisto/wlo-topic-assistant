docker rm -f wlo-topics-py
docker run wlo-topics-py python3 -m wlo_topic_assistant.topic_assistant "$1"
