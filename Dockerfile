FROM python:buster

ADD . .

RUN pip3 install --upgrade pip
RUN pip3 install .
RUN python -m nltk.downloader stopwords


