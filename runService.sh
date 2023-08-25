docker rm -f wlo-topic-assistant
docker run  -p 8080:8080 --name wlo-topic-assistant wlo-topics-py python3 -m wlo_topic_assistant.webservice $*
