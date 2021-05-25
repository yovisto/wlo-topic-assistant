FROM python:buster

RUN pip3 install --upgrade pip
RUN pip3 install cherrypy
RUN pip3 install rdflib
RUN pip3 install treelib
RUN pip3 install nltk
RUN python -m nltk.downloader stopwords

