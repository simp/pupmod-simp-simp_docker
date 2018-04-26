# Dangerfile!
# vi:syntax=ruby

# Sometimes it's a README fix, or something like that - which isn't relevant for
# including in a project's CHANGELOG for example
declared_trivial = github.pr_title.include? '#trivial'

has_puppet_changes = !git.modified_files.grep(/.pp$/).empty?
has_hiera_changes = !git.modified_files.grep(/^hieradata\/.yaml$|^data\/.yaml$|.pp$/).empty?
has_spec_changes = !git.modified_files.grep(/spec/).empty?
has_acceptance_changes = !git.modified_files.grep(/spec\/acceptance\/suites/).empty?

warn('Be sure to run the acceptance tests!') if has_acceptance_changes

if has_puppet_changes && !has_spec_changes
  warn('There are changes in manifests, but not tests. That\'s OK as long as you\'re refactoring existing code.', sticky: false)
end

changelog.have_you_updated_changelog?

warn('PR is classed as Work in Progress') if github.pr_title.include? 'WIP'

warn('Big PR') if git.lines_of_code > 500

if github.pr_body.length < 5
  warn 'Please provide a summary in the Pull Request description'
end

if !git.modified_files.include?('CHANGELOG') && has_puppet_changes
  warn('Please include a CHANGELOG entry when changing version).')
end

unless github.api.organization_member?('simp', github.pr_author)
  message(':tada: Thanks for your contribution!')
end

string_reference = `puppet strings generate --format markdown`
unless string_reference.include? '100.00% documented'
  fail('Parts of the code are not documented! See the output of `puppet strings generate --format markdown`')
elsif string_reference.include? 'warning'
  warn('There are some warnings from puppet strings! See the output of `puppet strings generate --format markdown`')
end

if system('git diff --exit-code REFERENCE.md')
  fail('Run `puppet strings generate --format markdown` and update the REFERENCE.md')
end

# We can totally do linting in here, like yaml validating and rpm stuff.

