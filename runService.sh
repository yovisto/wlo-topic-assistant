
docker build --tag wlo-topic-py .

docker run  -p 8080:8080 -d --name wlo-topic-assistant -v `pwd`/src:/scr wlo-topic-py python3 /scr/webservice.py 