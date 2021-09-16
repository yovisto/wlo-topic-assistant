# -*- coding: utf-8 -*-

#!pip3 install rdflib
#!pip3 install treelib

# https://github.com/openeduhub/oeh-metadata-vocabs/blob/master/oehTopics.ttl

import re, rdflib, sys, json
from treelib import Node, Tree
from rdflib.namespace import RDF, SKOS
from rdflib import URIRef
import nltk
#nltk.download('stopwords')
from nltk.corpus import stopwords
STOPWORDS = set(stopwords.words('german')).union(set(stopwords.words('english')))


class TopicAssistant:

    def normalize(self, s):
        s = re.sub('[^A-Za-z0-9öüäÖÄÜß]+', ' ', s)
        return s.lower()

    def __init__(self):

        # create a RDF graph
        g = rdflib.Graph()

        result = g.parse("https://raw.githubusercontent.com/openeduhub/oeh-metadata-vocabs/master/oehTopics.ttl", format="ttl")
        #result = g.parse("oehTopics.ttl", format="ttl")

        tree = Tree()
        #find top level node
        for s, p, o in g.triples((None, RDF.type, SKOS.ConceptScheme)):
            #print (s, p, o)
            tree.create_node("WLO", s, data={'w':0, 'uri': s})
            for s2, p2, o2 in g.triples((s, SKOS.hasTopConcept, None)):
                #print (s2, p2, o2)
                tree.create_node(o2, o2, parent=s, data={'w':0, 'uri': o2})
        
        foundSth = True
        while foundSth:
            foundSth = False
            for node in tree.all_nodes():
                n = URIRef(node.tag)
                for s, p, o in g.triples((None, SKOS.broader, n)):
                    if not tree.contains(s):
                        tree.create_node(s, s, parent=node, data={'w':0})
                        foundSth = True


        for node in tree.all_nodes():
            for s, p, o in g.triples(( URIRef(node.identifier) , SKOS.prefLabel, None)):
                node.tag=o
                node.data['label']=o


        keywords={}
        for s, p, o in g.triples((None, URIRef("https://schema.org/keywords"), None)):
            #print (s, o)
            n = self.normalize(o)
            if len(n)>2:
                try:
                    keywords[s].append(n)
                except:
                    keywords[s]=[]
                    keywords[s].append(n)

        for s, p, o in g.triples(( None , SKOS.prefLabel, None)):
            n = self.normalize(o)
            if len(n)>2:
                try:
                    if not n in keywords[s]:
                        keywords[s].append(n)
                except:
                    keywords[s]=[]
                    keywords[s].append(n)
            
        self.keywords = keywords
        self.tree = tree


    def go(self, exampleText):
        T = Tree(self.tree, deep=True)

        t=[]
        for tok in self.normalize(exampleText).split(' '):
            if not tok in STOPWORDS:
                t.append(tok)
        ntext = " " + " ".join(t) + " "
        #print (ntext)
        for c in self.keywords.keys():
            for k in self.keywords[c]:
                        
                        if ntext.find(" " + k + " ")>-1 :                        
                            T.get_node(c).data['w']=T.get_node(c).data['w']+1
                            T.get_node(c).data['match']=k 
                            #print (c, k)

        # propagate data to the root
        for d in range (T.depth(), -1, -1):    
            #print ("L", d)
            # für jeden knoten:
            for node in T.all_nodes():
                if d == T.depth(node):
                    # wenn er data =0 hat, ermittle data aus seinen kindern
                    if node.data!=None and node.data['w'] > 0:  

                        p = T.parent(node.identifier)
                        if p:
                            p.data['w'] = p.data['w'] + node.data['w']

        for node in T.all_nodes(): 
            #print (node, node.is_root())
            if node and not node.is_root() and node.data!=None and node.data['w'] == 0:
                #print (node.data, T.parent(node.identifier).data)
                if (T.contains(node.identifier)):
                    T.remove_node(node.identifier)
            else:
                if node and not node.is_root() and node.data!=None:
                    node.tag = node.tag + " (" + str(node.data['w']) + ")"
                    if 'match' in node.data.keys():
                        node.tag = node.tag + " [" + node.data['match'] + "]"
        T.show(key=lambda node: node.data["w"], reverse=True, idhidden=True) 

        return T.to_dict(with_data=True, key=lambda node: node.data["w"], sort=True, reverse=True)

if __name__ == '__main__':	

	text = sys.argv[1]
	a = TopicAssistant()
	print(json.dumps(a.go(text)))

