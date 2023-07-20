import cherrypy, json, sys
from wlo_topic_assistant.topic_assistant import TopicAssistant
from wlo_topic_assistant.topic_assistant2 import TopicAssistant2

a = None
a2 = None

class WebService:

   @cherrypy.expose
   @cherrypy.tools.json_out()
   @cherrypy.tools.json_in()
   def topics(self):
      data = cherrypy.request.json
      print (data)
      output = a.go(data["text"])
      return output


   @cherrypy.expose
   @cherrypy.tools.json_out()
   @cherrypy.tools.json_in()
   def topics2(self):
      data = cherrypy.request.json
      print (data)
      output = a2.go(data["text"])
      return output
   
def main():
   global a, a2
   a = TopicAssistant()
   a2 = TopicAssistant2()

   # listen to requests from any incoming IP address
   cherrypy.server.socket_host = "0.0.0.0"
   cherrypy.quickstart(WebService())


if __name__ == '__main__':
   main()

