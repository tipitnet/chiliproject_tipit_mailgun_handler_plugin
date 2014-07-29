require_relative '../test_helper'
require_relative '../../app/models/project_detection_strategy'

class ProjectDetectionStrategyTest < ActiveSupport::TestCase

	def setup
  	ProjectDetectionStrategy.global_inbox='inbox-project'
  	@mock_user = Object.new
    @mock_user.stubs(:anonymous?).returns(false)
    @default_project = 'project1'
    @project = Project.new
    @project.identifier = @default_project
    @mock_user.stubs(:default_project).returns(@project)
	end

  def test_return_user_default_project_when_no_project_specified
    email_address = "chiliproject@test.com"

    detected_project = ProjectDetectionStrategy.new.detect_project(email_address, @mock_user)

    assert_equal(@default_project, detected_project)
  end

  def test_return_specified_project_when_not_anonymous_user_and_project_specfied_in_address
    email_address = "chiliproject+project2@test.com"

    detected_project = ProjectDetectionStrategy.new.detect_project(email_address, @mock_user)

    assert_equal('project2', detected_project)
  end

  def test_return_global_inbox_when_anonymous_user_and_no_project_specfied
    email_address = "chiliproject@test.com"
    @mock_user.stubs(:anonymous?).returns(true)
    @mock_user.stubs(:default_project).returns(nil)

    detected_project = ProjectDetectionStrategy.new.detect_project(email_address, @mock_user)

    assert_equal(ProjectDetectionStrategy.global_inbox, detected_project)
  end

  def test_return_specified_project_when_anonymous_user_and_project_specfied_in_address
    email_address = "chiliproject+project3@test.com"
    @mock_user.stubs(:anonymous?).returns(true)
    @mock_user.stubs(:default_project).returns(nil)

    detected_project = ProjectDetectionStrategy.new.detect_project(email_address, @mock_user)

    assert_equal('project3', detected_project)
  end

end