# SaltStack Dockerfiles

## Introduction

This repository contains two **Dockerfile**s of [*SaltStack*](https://http://saltstack.com) for [Docker](https://www.docker.com/)'s automated build published to the public [Docker Hub Registry](https://registry.hub.docker.com/).

![Demo in action](demo/result.gif)

In particular, this repository contains two Docker images:

* [**saltstack-master**](https://registry.hub.docker.com/u/mbologna/saltstack-master): a SaltStack master container image. This salt setup accepts all minions that connects to it and comes with netapi module (cherrypy) enabled.
This container works with `supervisord` to automatically launch `salt-master` and `salt-api` daemons.  
* [**saltstack-minion**](https://registry.hub.docker.com/u/mbologna/saltstack-minion): a SaltStack minion container image.

## Base Docker image

* [opensuse 42.2](https://hub.docker.com/_/opensuse/)

## Dependencies

* [Docker](https://www.docker.com/)

## Usage

### Start `saltstack-master` container

```bash
docker run -d --hostname saltmaster --name saltmaster -v `pwd`/srv/salt:/srv/salt -p 8000:8000 -ti mbologna/saltstack-master
```

### Start `saltstack-minion` container (could be more than one!)

*  You can start one minion...

  ```bash
  docker run -d --hostname saltminion --name saltminion --link saltmaster:salt mbologna/saltstack-minion
  ```

*  or you can deploy an army of minions:

  ```bash
  for i in {1..10}; do docker run -d --hostname saltminion$i --name saltminion$i --link saltmaster:salt mbologna/saltstack-minion ; done
  ```

### Run Salt via command line

```bash
docker exec saltmaster /bin/sh -c "salt '*' cmd.run 'uname -a'"
```

```
  saltminion3:
      Linux saltminion3 4.4.57-18.3-default #1 SMP Thu Mar 30 06:39:47 UTC 2017 (39c8557) x86_64 x86_64 x86_64 GNU/Linux
  saltminion1:
      Linux saltminion1 4.4.57-18.3-default #1 SMP Thu Mar 30 06:39:47 UTC 2017 (39c8557) x86_64 x86_64 x86_64 GNU/Linux
  saltminion2:
      Linux saltminion2 4.4.57-18.3-default #1 SMP Thu Mar 30 06:39:47 UTC 2017 (39c8557) x86_64 x86_64 x86_64 GNU/Linux
```
### Run Salt via NetAPI

1. Get a token to use in all subsequent calls:
  ```bash
  curl -sS http://localhost:8000/login -c ~/cookies.txt -H 'Accept: application/json' -d username=saltdev -d password=saltdev -d eauth=pam
  ```
  ```
  {
    "return": [
    {
      "perms": [
      ".*"
      ],
      "start": 1446379166.406894,
      "token": "4072d45939ad1a33ffbe0565ec7d15d0cf2e24c2",
      "expire": 1446422366.406895,
      "user": "saltdev",
      "eauth": "pam"
    }
    ]
  }
  ```
2. Invoke Salt using saved token:
  ```bash
  curl -sS http://localhost:8000 -b ~/cookies.txt -H 'Accept: application/json' -d client=local -d tgt='*' -d fun=cmd.run -d arg="uptime"
  ```
  ```
  {
    "return": [
      {
        "saltminion1": " 23:55pm  up 2 days  8:28,  0 users,  load average: 1.31, 1.97, 1.70",
        "saltminion2": " 23:55pm  up 2 days  8:28,  0 users,  load average: 1.31, 1.97, 1.70",
        "saltminion3": " 23:55pm  up 2 days  8:28,  0 users,  load average: 1.31, 1.97, 1.70"
      }
    ]
  }
  ```

### Applying Salt states

A `<pwd>/srv/salt` directory has been created during the startup of the `saltmaster` container. Place your SLS state definition in it.

A Salt state example follows:

```bash
% cat srv/salt/tmux.sls
```

```yaml
tmux:
  pkg.installed
```

Now you can apply defined state file to your minions:

```bash
docker exec saltmaster /bin/sh -c "salt saltminion1 state.apply tmux"
```

```
  saltminion1:
  ----------
            ID: tmux
      Function: pkg.installed
        Result: True
       Comment: The following packages were installed/updated: tmux
       Started: 12:25:42.977107
      Duration: 22305.267 ms
       Changes:   
                ----------
                tmux:
                    ----------
                    new:
                        2.2-1.3
                    old:

  Summary for saltminion1
  ------------
  Succeeded: 1 (changed=1)
  Failed:    0
  ------------
  Total states run:     1
  Total run time:  22.305 s
```

## Caveats and security

* `saltstack-master` exposes port `8000/tcp` (**NO SSL**) in order to consume `salt-api` via its HTTP interface.

  **WARNING**: your credentials travel in plain-text.

* `saltstack-master` works with PAM authentication module.
A `saltdev` user (password: `saltdev`) has been added to the container.

* You must be `root` to write files in `/srv/salt` in the container host.
