import json, sys, rdflib
from wlo_topic_assistant.topic_assistant import TopicAssistant
import pandas as pd
from rdflib.namespace import RDF, SKOS

g = rdflib.Graph()

mapping = {}
result = g.parse("https://raw.githubusercontent.com/openeduhub/oeh-metadata-vocabs/master/oehTopics.ttl", format="ttl")
for s, p, o in g.triples((None, SKOS.relatedMatch, None)):
   #print (s, o)
   #if o.endswith("460"):
      #print (s, o)
   mapping[str(s)]=o


a = TopicAssistant()


#df = pd.read_csv("../../wlo-classification/data/wirlernenonline.oeh.csv",sep=',')
df = pd.read_csv("wirlernenonline2_wokw.csv",sep=',')
df.columns = ['discipline', 'text']

atfirst = 0
atsecond = 0
atall = 0
notfound = 0
num = 0

for index, row in df.iterrows():
    num+=1
    if (num>1000):
      break
    gtdis = row['discipline']

    print ("########################################################")
    print (row['text'])

    result = a.go(row['text'])
    match = False
    idx = 0
    if not 'children' in result['WLO'].keys():
      notfound+=1
    else:
       for i in range(len(result['WLO']['children'])):
          if (idx<=i):
             for k in result['WLO']['children'][idx].keys():      
               uri = result['WLO']['children'][idx][k]['data']['uri']      
               label = result['WLO']['children'][idx][k]['data']['label']
               #print (uri, label)
               dis = mapping[uri].replace('http://w3id.org/openeduhub/vocabs/discipline/','')
               #print (dis)
               idx+=1

               print (gtdis, dis)

               if idx==1 and gtdis == dis:
                  atfirst+=1
               if idx==2 and gtdis == dis:
                  atsecond+=1
               if gtdis == dis:
                  atall+=1
                  match = True
                  break
    print ("")
    print (atfirst, atsecond, atall, num, notfound, match)

    relfirst = atfirst/num
    relsecond = atsecond/num
    relall = atall/num

    relfs = (atfirst+atsecond)/num

    print (relfirst, relsecond, relfs, relall)


