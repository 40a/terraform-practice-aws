#!/bin/bash
#Chef run list
cat << "EOF" > /cookbooks/node.json
{
    "gocd-agent-linux": {"server-host-name": "${gocd_server}"},
    "run_list": ["recipe[gocd-agent-linux]"]
}
EOF
sudo chef-solo -c /cookbooks/solo.rb -j /cookbooks/node.json -l debug > /home/ubuntu/startup.log && echo "Server ready." | wall