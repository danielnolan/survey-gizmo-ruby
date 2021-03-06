require 'spec_helper'
describe 'Survey Gizmo Resource' do

  let(:create_attributes_to_compare) { }
  let(:get_attributes_to_compare) { }

  describe SurveyGizmo::Resource do
    before(:each) do
      SurveyGizmo.setup(user: 'test@test.com', password: 'password')
    end

    let(:described_class)   { SurveyGizmoSpec::ResourceTest }
    let(:create_attributes) { {title: 'Spec', test_id: 5} }
    let(:update_attributes) { {title: 'Updated'} }
    let(:first_params)      { {id: 1, test_id: 5} }
    let(:get_attributes)    { create_attributes.merge(id: 1) }
    let(:uri_paths){
      {
        get:    '/test/1',
        create: '/test/5/resource',
        update: '/test/5/resource/1',
        delete: '/test/5/resource/1'
      }
    }

    it '#reload' do
      stub_request(:get, /#{@base}/).to_return(json_response(true, get_attributes))
      obj = described_class.new(get_attributes.merge(update_attributes))
      obj.attributes.reject {|k,v| v.blank? }.should == get_attributes.merge(update_attributes)
      obj.reload
      obj.attributes.reject {|k,v| v.blank? }.should == get_attributes
    end

    it 'should raise an error if params are missing' do
      lambda {
        SurveyGizmoSpec::ResourceTest.destroy(test_id: 5)
      }.should raise_error(SurveyGizmo::URLError, 'Missing RESTful parameters in request: `:id`')
    end

    it_should_behave_like 'an API object'
    it_should_behave_like 'an object with errors'

    context '#convert_filters_into_query_string' do
      let(:page)    { 2 }
      let(:filters) { {page: page, filters: [{field: 'istestdata', operator: '<>', value: 1}] }}

      it 'should generate the correct page request' do
        expect(SurveyGizmoSpec::ResourceTest.convert_filters_into_query_string(page: page)).to eq("?page=#{page}")
      end

      it 'should generate the correct filter fragment' do
        expect(SurveyGizmoSpec::ResourceTest.convert_filters_into_query_string(filters)).to eq("?filter%5Bfield%5D%5B0%5D=istestdata&filter%5Boperator%5D%5B0%5D=%3C%3E&filter%5Bvalue%5D%5B0%5D=1&page=#{page}")
      end
    end
  end

  describe SurveyGizmo::API::Survey do
    let(:create_attributes) { { title: 'Spec', type: 'survey', status: 'In Design' } }
    let(:get_attributes)    { create_attributes.merge(first_params) }
    let(:update_attributes) { { title: 'Updated'} }
    let(:first_params)      { { id: 1234} }
    let(:uri_paths){
      h = { :create => '/survey' }
      h.default = '/survey/1234'
      h
    }

    it_should_behave_like 'an API object'
    it_should_behave_like 'an object with errors'

    it 'should parse the number of completed records correctly' do
      survey = described_class.new('statistics' => [['Partial', 2], ['Disqualified', 28], ['Complete', 15]])
      expect(survey.number_of_completed_responses).to eq(15)
    end
  end

  describe SurveyGizmo::API::Question do
    let(:base_params)       { {survey_id: 1234, page_id: 1} }
    let(:create_attributes) { base_params.merge(title: 'Spec Question', type: 'radio', properties: {'required' => true, 'option_sort' => false}) }
    let(:update_attributes) { base_params.merge(title: 'Updated') }
    let(:first_params)      { base_params.merge(id: 1) }
    let(:get_attributes)    { create_attributes.merge(id: 1) }
    let(:uri_paths) {
      { :get =>    '/survey/1234/surveyquestion/1',
        :create => '/survey/1234/surveypage/1/surveyquestion',
        :update => '/survey/1234/surveypage/1/surveyquestion/1',
        :delete => '/survey/1234/surveypage/1/surveyquestion/1'
      }
    }

    it_should_behave_like 'an API object'
    it_should_behave_like 'an object with errors'

    it 'should handle the title hash returned from the API' do
      expect(described_class.new('title' => {'English' => 'Some title'}).title).to eq('Some title')
    end

    it 'should handle the _subtype key' do
      described_class.new(:_subtype => 'radio').type.should == 'radio'
    end

    it 'should have no subquestions' do
      expect(described_class.new().sub_questions).to eq([])
    end

    it 'should find the survey' do
      stub_request(:get, /#{@base}\/survey\/1234/).to_return(json_response(true, get_attributes))
      described_class.new(base_params).survey
      a_request(:get, /#{@base}\/survey\/1234/).should have_been_made
    end

    context 'with subquestions' do
      let(:parent_id) { 33 }
      let(:question_with_subquestions) { described_class.new(id: parent_id, survey_id: 1234, sub_question_skus: [1, 2])}
      it 'should have 2 subquestions and they should have the right parent question' do
        stub_request(:get, /#{@base}/).to_return(json_response(true, get_attributes))
        expect(question_with_subquestions.sub_questions.size).to eq(2)

        question_with_subquestions.sub_questions.first.parent_question
        a_request(:get, /#{@base}\/survey\/1234\/surveyquestion\/#{parent_id}/).should have_been_made
      end
    end
  end

  describe SurveyGizmo::API::Option do
    let(:survey_and_page)   { {survey_id: 1234, page_id: 1} }
    let(:create_attributes) { survey_and_page.merge(question_id: 1, title: 'Spec Question', value: 'Spec Answer') }
    let(:update_attributes) { survey_and_page.merge(question_id: 1, title: 'Updated') }
    let(:first_params)      { survey_and_page.merge(id: 1, question_id: 1) }
    let(:get_attributes)    { create_attributes.merge(id: 1) }
    let(:uri_paths) {
      h = { :create => '/survey/1234/surveypage/1/surveyquestion/1/surveyoption' }
      h.default = '/survey/1234/surveypage/1/surveyquestion/1/surveyoption/1'
      h
    }

    it_should_behave_like 'an API object'
    it_should_behave_like 'an object with errors'
  end

  describe SurveyGizmo::API::Page do
    let(:create_attributes) { {:survey_id => 1234, :title => {'English' => 'Spec Page'}} }
    let(:get_attributes)    { create_attributes.merge(:id => 1) }
    let(:update_attributes) { {:survey_id => 1234, :title => 'Updated'} }
    let(:first_params)      { {:id => 1, :survey_id => 1234 } }
    let(:uri_paths){
      h = { :create => '/survey/1234/surveypage' }
      h.default = '/survey/1234/surveypage/1'
      h
    }

    it_should_behave_like 'an API object'
    it_should_behave_like 'an object with errors'
  end

  describe SurveyGizmo::API::Response do
    let(:create_attributes) { {:survey_id => 1234, :datesubmitted => "2015-04-15 05:46:30" } }
    let(:create_attributes_to_compare) { create_attributes.merge(:datesubmitted => Time.parse("2015-04-15 05:46:30 EST")) }
    let(:get_attributes)    { create_attributes.merge(:id => 1) }
    let(:get_attributes_to_compare)    { create_attributes_to_compare.merge(:id => 1) }
    let(:update_attributes) { {:survey_id => 1234, :title => 'Updated'} }
    let(:first_params)      { {:id => 1, :survey_id => 1234 } }
    let(:uri_paths){
      h = { :create => '/survey/1234/surveyresponse' }
      h.default = '/survey/1234/surveyresponse/1'
      h
    }

    it_should_behave_like 'an API object'
    it_should_behave_like 'an object with errors'
  end

end
