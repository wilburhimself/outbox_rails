module OutboxRails
  class Engine < ::Rails::Engine
    isolate_namespace OutboxRails

    initializer "outbox_rails.migrations" do |app|
      unless app.config.paths["db/migrate"].include?(root.join("db/migrate").to_s)
        app.config.paths["db/migrate"] << root.join("db/migrate").to_s
      end
    end
  end
end
