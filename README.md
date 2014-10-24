# Hello Mesos World

## Creating a Marathon app:

```bash
curl -XPOST \
  -d @rails-marathon.json \
  -H"Content-Type: application/json" \
  -v http://[marathon_ip]:8080/v2/apps
```
