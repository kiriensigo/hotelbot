threads_count = ENV.fetch("RAILS_MAX_THREADS", 3)
threads threads_count, threads_count

# Specifies the `port` that Puma will listen on to receive requests; default is 3000.
port ENV.fetch("PORT", 3000)

# Allow puma to be restarted by `bin/rails restart` command.
plugin :tmp_restart

# Specify the PID file. Defaults to tmp/pids/server.pid in development.
# In other environments, only set the PID file if requested.
pidfile ENV["PIDFILE"] if ENV["PIDFILE"]

# 環境に応じてワーカー数を設定
workers ENV.fetch("WEB_CONCURRENCY") { 2 }

# プリロードを有効化
preload_app!

# Specifies the `environment` that Puma will run in.
environment ENV.fetch("RAILS_ENV") { "production" }

# アプリケーションのディレクトリを指定
directory ENV.fetch("RAILS_ROOT") { "." }

# ワーカーブート時の処理を追加
on_worker_boot do
  ActiveRecord::Base.establish_connection if defined?(ActiveRecord)
end

# 低メモリ使用のためのGC設定
before_fork do
  GC.copy_on_write_friendly = true if GC.respond_to?(:copy_on_write_friendly=)
end