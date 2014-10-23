#!/usr/bin/env bash
ssh-add ~/.ssh/Chef5_8.pem

knife ec2 server create \
  -r 'role[mesos_master]' \
  -I 'ami-9eaa1cf6' \
  -f m3.large \
  -S 'Chef5_8' \
  --security-group-ids 'sg-22777547' \
  -s 'subnet-61985916' \
  -T 'Name=Mesos-Master' \
  --associate-public-ip \
  --ssh-user 'ubuntu'
