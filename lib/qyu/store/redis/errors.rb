(Dir["#{File.dirname(__FILE__)}/errors/*.rb"]).each do |path|
  require path
end
