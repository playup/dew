After("@aws") do
  if !ENV['KEEP_TEST_ARTIFACTS']
    if @environment_name
      run_and_capture("./bin/dew --region #{@region} --account #{@account_name} environments destroy -f #{@environment_name}", 'destroy-environment')
    end
    if @ami_name
      run_and_capture("./bin/dew --region #{@region} --account #{@account_name} amis destroy -f #{@ami_name}", 'destroy-ami')
    end
  end
end
