#!/bin/bash
yum install curl jq -y    #install initial tool
echo "--------------"
echo "install initial tool completed"

 for i in /etc/cinder/cinder.conf /etc/glance/glance-api.conf /etc/keystone/keystone.conf /etc/nova/nova.conf /etc/neutron/neutron.conf /usr/lib/python2.7/site-packages/nova/console/websocketproxy.py
 do
   b=${i}"-bk-"$(date "+%Y-%m-%d")"-"$RANDOM
   cp $i $b
echo "--------------"
echo "file $i copied to $b"
 done


Admin_token=$(sed -n "/^\[DEFAULT\]/,/^\[/ {/^admin_token/ p} " /etc/keystone/keystone.conf |awk -F= '{print $2}')
echo "Admin_token="$Admin_token
if [ -z $Admin_token ]
then 
   echo "no Admin_token is provided"
   exit 1
 fi
 
 User_id=$(curl -X GET http://127.0.0.1:35357/v3/users -H "User-Agent: python-keystoneclient" -H "X-Auth-Token: $Admin_token"  | jq . |sed -n '/"name": "admin"/,/"id"/{/"id"/ p}'|awk -F\" '{print$4}')
 Role_id=$(curl -X GET http://127.0.0.1:35357/v3/roles -H "User-Agent: python-keystoneclient" -H "X-Auth-Token: $Admin_token" | jq . | grep "\"admin\"" -B 6 |grep "\"id"|awk -F\" '{print $4}')
 curl -X PUT -H "X-Auth-Token: $Admin_token" http://127.0.0.1:35357/v3/domains/default/users/$User_id/roles/$Role_id #add assignment to role admin,user admin,domain default
 curl -X PUT -H "X-Auth-Token: $Admin_token" http://127.0.0.1:35357/v3/OS-INHERIT/domains/default/users/$User_id/roles/$Role_id/inherited_to_projects #inherit role admin to all the projects under domain default
  echo "-------------------------"
 echo "user admin promoting completed, now user admin have domain scope admin priviledge "
 
 sed -i  "/^SESSION_TIMEOUT/ s/^SESSION_TIMEOUT.*$/SESSION_TIMEOUT = 190000/" /etc/openstack-dashboard/local_settings   #modify dashboard session timeout value
  echo "-------------------------"
 echo "dashboard session timeout value set to  190000 sedonds"
 sed -i  "/^\[token\]/,/^\[/ s/^expiration.*/expiration=86400/g" /etc/keystone/keystone.conf #modify token timeout value to 1 day
   echo "-------------------------"
 echo "dashboard session timeout value set to 1 day"
 
 for i in /etc/cinder/cinder.conf /etc/glance/glance-api.conf /etc/keystone/keystone.conf /etc/nova/nova.conf /etc/neutron/neutron.conf 
 do
   sed -i -e "/^\[cors\]/ a allowed_origin\=\*" -e "/^\[cors\]/ a expose_headers\=authorization,content-type,X-Auth-Token,X-Openstack-Request-Id,X-Subject-Token,X-Requested-With" -e "/^\[cors\]/ a allow_headers\=authorization,content-type,X-Auth-Token,X-Openstack-Request-Id,X-Subject-Token,X-Project-Id,X-Project-Name,X-Project-Domain-Id,X-Project-Domain-Name,X-Domain-Id,X-Domain-Name,X-Requested-With" $i
    echo "-------------------------"
     echo "cors setting for $i done"
 done
 
 sed -i '/if origin_hostname not in expected_origin_hostnames:/,+2 s/^/#/' /usr/lib/python2.7/site-packages/nova/console/websocketproxy.py
 
   echo "-------------------------"
 echo "web consol python code have been modified"
 
 systemctl restart httpd openstack-cinder-api.service openstack-nova-api.service openstack-glance-api.service neutron-server.service
 
    echo "-------------------------"
 echo "service httpd openstack-cinder-api.service openstack-nova-api.service openstack-glance-api.service neutron-server.service have been restarted "
