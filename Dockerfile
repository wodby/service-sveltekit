ARG WODBY_BASE_IMAGE
FROM ${WODBY_BASE_IMAGE}

ARG COPY_FROM
COPY --chown=node:node ${COPY_FROM} /usr/src/app

RUN npm run build

CMD ["npm", "run", "start"]
