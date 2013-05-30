Feature: AWS High-Availibility Release
  Scenario: Requires the autoscaling group name to be passed in
    When I run `aws-ha-release.rb`
    Then the output should contain "You must specify the AutoScaling Group Name: aws-ha-release.rb -a <group name>"
    And the exit status should not be 0
    When I run `aws-ha-release.rb -a test_group`
    Then the exit status should be 0
    When I run `aws-ha-release.rb --as-group-name test_group`
    Then the exit status should be 0

  Scenario: Optionally allows the user to specify an ELB timeout
    When I run `aws-ha-release.rb -a test_group -t not_valid_input`
    Then the exit status should not be 0
    When I run `aws-ha-release.rb -a test_group -t 100`
    Then the exit status should be 0
    When I run `aws-ha-release.rb -a test_group --elb-timeout 100`
    Then the exit status should be 0

  Scenario: Optionally allows the user to specify a region
    When I run `aws-ha-release.rb -a test_group -r`
    Then the exit status should not be 0
    When I run `aws-ha-release.rb -a test_group -r test_region`
    Then the exit status should be 0
    When I run `aws-ha-release.rb -a test_group --region test_region`
    Then the exit status should be 0

  Scenario: Optionally allows the user to specify an inservice time allowed
    When I run `aws-ha-release.rb -a test_group -i not_valid_input`
    Then the exit status should not be 0
    When I run `aws-ha-release.rb -a test_group -i 100`
    Then the exit status should be 0
    When I run `aws-ha-release.rb -a test_group --inservice-time-allowed 100`
    Then the exit status should be 0

  Scenario: Optionally allows the user to pass in the aws_access_key and aws_secret_key
    When I run `aws-ha-release.rb -a test_group -o testaccesskey`
    Then the exit status should not be 0
    When I run `aws-ha-release.rb -a test_group -o testaccesskey -s testsecretkey`
    Then the exit status should be 0
    When I run `aws-ha-release.rb -a test_group --aws-access-key testaccesskey --aws-secret-key testsecretkey`
    Then the exit status should be 0
