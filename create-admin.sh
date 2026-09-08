#!/bin/bash
cd /var/discourse
sudo ./launcher enter app -- bundle exec rails runner "
u = User.new(
  name: 'Gerald Velasquez',
  username: 'gerald',
  email: 'gerald512@gmail.com',
  password: 'PreUni2024!',
  approved: true
)
u.activate
u.save!
u.grant_admin!
SiteSetting.wizard_enabled = false rescue nil
puts 'DONE: ' + u.username
"
