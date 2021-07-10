FROM node:latest

WORKDIR /app

ADD mocks.json .

EXPOSE 5000

RUN npm i -g json-graphql-server

CMD json-graphql-server mocks.json