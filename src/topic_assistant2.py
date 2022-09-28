# -*- coding: utf-8 -*-

#!pip3 install rdflib
#!pip3 install treelib

# https://github.com/openeduhub/oeh-metadata-vocabs/blob/master/oehTopics.ttl
import pandas as pd
from sentence_transformers import SentenceTransformer
import re, rdflib,json
from treelib import Node, Tree
from rdflib.namespace import RDF, SKOS
from rdflib import URIRef
from sklearn.metrics.pairwise import cosine_similarity
from sklearn.metrics.pairwise import euclidean_distances
import numpy as np
import nltk, sys
#nltk.download('stopwords')
from nltk.corpus import stopwords
STOPWORDS = set(stopwords.words('german')).union(set(stopwords.words('english')))
STOPWORDS.add('anhand')
import time

class TopicAssistant2:

    def normalize(self, s):
        s = re.sub('[^A-Za-z0-9öüäÖÄÜß]+', ' ', s)
        return s.lower()

    def __init__(self):

        # create a RDF graph
        g = rdflib.Graph()

        # parse in an RDF file hosted on the Internet
        #result = g.parse("https://raw.githubusercontent.com/openeduhub/oeh-metadata-vocabs/master/oehTopics.ttl", format="ttl")
        result = g.parse("oehTopics.ttl", format="ttl")

        tree = Tree()
        #find top level node
        for s, p, o in g.triples((None, RDF.type, SKOS.ConceptScheme)):
            #print (s, p, o)
            tree.create_node("WLO", s, data={'w':0, 'uri': s})
            for s2, p2, o2 in g.triples((s, SKOS.hasTopConcept, None)):
                #print (s2, p2, o2)
                tree.create_node(o2, o2, parent=s, data={'w':0, 'uri': o2})
                #break
            
        foundSth = True
        #für jeden Knoten finde Kindknoten
        while foundSth:
            foundSth = False
            #print (len(tree))
            for node in tree.all_nodes():
                #print (node.tag)
                n = URIRef(node.tag)
                for s, p, o in g.triples((None, SKOS.broader, n)):
                    #print (s, tree.contains(s))
                    if not tree.contains(s):
                        tree.create_node(s, s, parent=node, data={'w':0})
                        foundSth = True


        for node in tree.all_nodes():
            for s, p, o in g.triples(( URIRef(node.identifier) , SKOS.prefLabel, None)):
                node.tag=o
                node.data['label']=o
                #print (o)

        vocabulary = {}
        
        ## create list of keywords
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
                try:
                    vocabulary[n]=vocabulary[n] + 1
                except:
                    vocabulary[n]=1

        # prefLabel
        for s, p, o in g.triples(( None , SKOS.prefLabel, None)):
            n = self.normalize(o)
            #print (n)
            if len(n)>2:
                try:
                    if not n in keywords[s]:
                        keywords[s].append(n)
                except:
                    keywords[s]=[]
                    keywords[s].append(n)
                try:
                    vocabulary[n]=vocabulary[n] + 1
                except:
                    vocabulary[n]=1                    
            
        self.vocabulary = vocabulary    
        self.keywords = keywords
        self.tree = tree
        
        self.model = SentenceTransformer('all-mpnet-base-v2')
        self.df = pd.DataFrame(self.genPaths(), columns=['id','text', 'path'])
        self.embeddings = self.model.encode(self.df['text']) 
        
    def genPaths(self):
        #print (str(len(self.tree.leaves())))
        docs = []
        for leaf in self.tree.leaves():
            #print ("-->", leaf.identifier)
            path = [nid for nid in self.tree.rsearch(leaf.identifier)][::-1]
            res = []
            for uriref in path:    
                if uriref in self.keywords.keys():                    
                    res.extend(self.keywords[uriref])
            docs.append([str(leaf.identifier), " ".join(res), " ".join(path)])
        return docs

    def go(self, exampleText):
        doc_e = self.model.encode([self.normalize(exampleText)])
        sim = cosine_similarity(self.embeddings, doc_e)
        #print (type(sim))
        #print (np.argsort(sim, axis=None))
        ix = (np.argsort(sim, axis=None))[-10:]
        #print (ix)
        #for i in reversed(ix):
        #    print ( str(sim[i]), df.iloc[i]["id"], df.iloc[i]["text"])    
        
        newTree = Tree(self.tree, deep=True)
        
        nodes = set()

        for i in reversed(ix):
            #print ( str(sim[i]), df.iloc[i]["id"], df.iloc[i]["path"])
            for n in self.df.iloc[i]["path"].split():
                nodes.add(n)                
                if (newTree.contains(URIRef(n))):
                    newTree.get_node(URIRef(n)).data['w']=newTree.get_node(URIRef(n)).data['w'] + sim[i][0]
                    
                
        #print (nodes)
        for node in newTree.all_nodes():   
            #print (node.identifier), node.identifier in nodes)
            node.tag = node.tag + " (" + str(node.data['w']) + ")"
            if not str(node.identifier) in nodes:
                if (newTree.contains(node.identifier)):
                    newTree.remove_node(node.identifier)

                    
        #print (len(newTree))
        newTree.show(key=lambda node: node.data["w"], reverse=True, idhidden=True) 
        return newTree.to_dict(with_data=True, key=lambda node: node.data["w"], sort=True, reverse=True)

if __name__ == '__main__':	

	text = sys.argv[1]
	a = TopicAssistant2()
	print(json.dumps(a.go(text)))

