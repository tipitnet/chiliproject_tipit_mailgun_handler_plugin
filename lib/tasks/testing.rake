namespace :test do
  namespace :tipit_mail_handler do

    desc 'Run all unit tests for chiliproject_tipit_mail_handler Plugin'
    Rake::TestTask.new(:unit) do |t|
      t.test_files = FileList['vendor/plugins/chiliproject_tipit_mail_handler/test/unit/*.rb']
      t.verbose = true
    end

    desc 'Run all functional tests for chiliproject_tipit_mail_handler Plugin'
    Rake::TestTask.new(:functional) do |t|
      t.test_files = FileList['vendor/plugins/chiliproject_tipit_mail_handler/test/functional/*.rb']
      t.verbose = true
    end

  end
end