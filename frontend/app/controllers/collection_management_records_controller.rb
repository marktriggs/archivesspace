class CollectionManagementRecordsController < ApplicationController
  skip_before_filter :unauthorised_access, :only => [:index, :show, :list, :new, :edit, :create, :update, :listrecords]
  before_filter :user_needs_to_be_a_viewer, :only => [:index, :show, :list]
  before_filter :user_needs_to_be_an_archivist, :only => [:new, :edit, :create, :update]

  def index
    @search_data = JSONModel(:collection_management).all(:page => 1)
  end

  def show
    @collection_management = JSONModel(:collection_management).find(params[:id], "resolve[]" => ["ref"])
  end

  def new
    @collection_management = JSONModel(:collection_management).new._always_valid!
    @collection_management.linked_records = [{}]
  end

  def edit
    @collection_management = JSONModel(:collection_management).find(params[:id], "resolve[]" => ["ref"])
  end

  def create
    handle_crud(:instance => :collection_management,
                :on_invalid => ->(){
                  render :action => :new
                },
                :on_valid => ->(id){
                  redirect_to :controller => :collection_management_records, :action => :index, :id => id
                })
  end

  def update
    handle_crud(:instance => :collection_management,
                :obj => JSONModel(:collection_management).find(params[:id]),
                :on_invalid => ->(){ render :action => :edit },
                :on_valid => ->(id){
                  flash[:success] = "Collection Management Record Saved"
                  redirect_to :controller => :collection_management_records, :action => :index
                })
  end


  def listrecords
    render :json => [] if params[:q].blank?

    render :json => JSONModel::HTTP.get_json(JSONModel(:collection_management).uri_for('linkable-records/list'),
                                             :q => params[:q])
  end

end
