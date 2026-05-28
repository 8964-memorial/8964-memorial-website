# Define an application-wide HTTP permissions policy. For further
# information see https://developers.google.com/web/updates/2018/06/feature-policy
#
# This is a static memorial site that needs none of these powerful features, so
# deny them all to reduce the abuse surface if content is ever injected.
Rails.application.config.permissions_policy do |f|
  f.camera      :none
  f.gyroscope   :none
  f.microphone  :none
  f.usb         :none
  f.geolocation :none
  f.payment     :none
end
