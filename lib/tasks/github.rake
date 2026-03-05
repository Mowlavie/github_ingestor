namespace :github do
  desc "Ingest GitHub push events. Set CONTINUOUS=true to poll indefinitely."
  task ingest: :environment do
    Github::IngestionRunner.new.run
  end
end
