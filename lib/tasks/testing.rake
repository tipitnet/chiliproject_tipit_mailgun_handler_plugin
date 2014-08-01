namespace :test do
  namespace :tipit_mailgun_handler do

    desc 'Run all unit tests for chiliproject_tipit_mail_handler Plugin'
    Rake::TestTask.new(:units) do |t|
      t.test_files = FileList['vendor/plugins/chiliproject_tipit_mailgun_handler/test/unit/*.rb']
      t.verbose = true
    end

    desc 'Run all integration tests for chiliproject_tipit_mail_handler Plugin'
    Rake::TestTask.new(:integration) do |t|
      t.test_files = FileList['vendor/plugins/chiliproject_tipit_mailgun_handler/test/integration/*.rb']
      t.verbose = true
    end

    desc 'Run all functional tests for chiliproject_tipit_mail_handler Plugin'
    Rake::TestTask.new(:functionals) do |t|
      t.test_files = FileList['vendor/plugins/chiliproject_tipit_mailgun_handler/test/functional/*.rb']
      t.verbose = true
    end

  end
end