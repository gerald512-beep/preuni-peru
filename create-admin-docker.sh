#!/bin/bash
sudo docker exec app bundle exec rails runner "
u = User.find_by_email('gerald512@gmail.com')
if u.nil?
  u = User.new(
    name: 'Gerald Velasquez',
    username: 'gerald',
    email: 'gerald512@gmail.com',
    password: 'PreUni2024!',
    approved: true
  )
  u.activate
  u.save!
  puts 'User created'
else
  puts 'User exists'
end
u.grant_admin!
u.save!
puts 'DONE: ' + u.username + ' admin=' + u.admin.to_s
"
