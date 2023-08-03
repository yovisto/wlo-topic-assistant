import argparse
import cherrypy, json, sys
from wlo_topic_assistant.topic_assistant import TopicAssistant
from wlo_topic_assistant.topic_assistant2 import TopicAssistant2

a = None
a2 = None


class WebService:
    @cherrypy.expose
    def _ping(self):
        pass

    @cherrypy.expose
    @cherrypy.tools.json_out()
    @cherrypy.tools.json_in()
    def topics(self):
        data = cherrypy.request.json
        print(data)
        output = a.go(data["text"])
        return output

    @cherrypy.expose
    @cherrypy.tools.json_out()
    @cherrypy.tools.json_in()
    def topics2(self):
        data = cherrypy.request.json
        print(data)
        output = a2.go(data["text"])
        return output


def main():
    global a, a2
    a = TopicAssistant()
    a2 = TopicAssistant2()

    # define CLI arguments
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--port", action="store", default=8080, help="Port to listen on", type=int
    )
    parser.add_argument(
        "--host", action="store", default="0.0.0.0", help="Hosts to listen to", type=str
    )

    # read passed CLI arguments
    args = parser.parse_args()

    # start the cherrypy service using the passed arguments
    cherrypy.server.socket_host = args.host
    cherrypy.server.socket_port = args.port
    cherrypy.quickstart(WebService())


if __name__ == "__main__":
    main()
