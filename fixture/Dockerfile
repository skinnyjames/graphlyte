FROM node:latest

WORKDIR /app

ADD mocks.json .

RUN npm i -g json-graphql-server@2.2.3

EXPOSE 5000

CMD ["json-graphql-server", "mocks.json", "--p", "5000"]