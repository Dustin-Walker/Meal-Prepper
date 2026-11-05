require "rake"

# Loads the app's rake tasks once per process and runs one with fresh state.
module RakeTaskHelper
  def run_rake_task(name, *args)
    Rails.application.load_tasks unless Rake::Task.task_defined?(name)
    task = Rake::Task[name]
    task.reenable
    task.invoke(*args)
  end
end
