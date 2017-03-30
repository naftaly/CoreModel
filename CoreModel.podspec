Pod::Spec.new do |s|
  s.name = 'CoreModel'

  s.version = '1.0.0'
  
  s.homepage = "https://github.com/naftaly/CoreModel"
  s.source = { :git => "https://github.com/naftaly/CoreModel.git", :tag => s.version }
  s.license = { :type => 'MIT', :file => 'LICENSE' }
  s.summary = 'Lightweight framework that simplifies the process of converting your data to usable objects.'

  s.social_media_url = 'https://twitter.com/naftaly'
  s.authors  = { 'Alexander Cohen' => 'naftaly@me.com' }

  s.requires_arc = true

  s.ios.deployment_target = '9.0'
	
  s.source_files = [ 'CoreModel/CMModel.?', 'CoreModel/CoreModel.h' ]
  s.public_header_files = [ 'CoreModel/CMModel.h', 'CoreModel/CoreModel.h' ]
end
