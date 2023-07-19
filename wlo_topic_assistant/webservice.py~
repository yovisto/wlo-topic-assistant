import cherrypy, json, sys
from topic_assistant import TopicAssistant
from topic_assistant2 import TopicAssistant2

a = None
a2 = None

class WebService(object):

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


if __name__ == '__main__':

   a = TopicAssistant()
   a2 = TopicAssistant2()

   config = {'server.socket_host': '0.0.0.0'}
   cherrypy.config.update(config)
   cherrypy.quickstart(WebService())	