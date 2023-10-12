FROM nginx:1.25.2-alpine3.18

HEALTHCHECK --interval=30s --timeout=3s \
  CMD curl -f http://127.0.0.1/ || exit 1
