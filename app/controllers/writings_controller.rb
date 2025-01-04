class WritingsController < ApplicationController
  allow_unauthenticated_access only: %i[ index show ]
  before_action :set_writing, only: %i[ show edit update destroy ]
  before_action :require_staff_and_admin, only: %i[ new create edit update destroy drafts ]

  # GET /writings or /writings.json
  def index
    resume_session
    @writings = Writing.published.order(published_at: :desc)
  end

  # GET /writings/drafts
  def drafts
    resume_session
    @writings = Writing.where(status: "draft").order(updated_at: :desc)
    render :index
  end

  # GET /writings/1 or /writings/1.json
  def show
    resume_session
  end

  # GET /writings/new
  def new
    @writing = Writing.new
  end

  # GET /writings/1/edit
  def edit
  end

  # POST /writings or /writings.json
  def create
    @writing = Writing.new(writing_params)
    @writing.user = Current.user
    @writing.slug = @writing.title.parameterize if @writing.title.present?

    respond_to do |format|
      if @writing.save
        format.html { redirect_to writing_path(@writing.slug), notice: "Writing was successfully created." }
        format.json { render :show, status: :created, location: @writing }
      else
        format.html { render :new, status: :unprocessable_entity }
        format.json { render json: @writing.errors, status: :unprocessable_entity }
      end
    end
  end

  # PATCH/PUT /writings/1 or /writings/1.json
  def update
    respond_to do |format|
      if @writing.update(writing_params)
        format.html { redirect_to writing_path(@writing.slug), notice: "Writing was successfully updated." }
        format.json { render :show, status: :ok, location: @writing }
      else
        format.html { render :edit, status: :unprocessable_entity }
        format.json { render json: @writing.errors, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /writings/1 or /writings/1.json
  def destroy
    @writing.destroy!

    respond_to do |format|
      format.html { redirect_to writings_url, notice: "Writing was successfully destroyed." }
      format.json { head :no_content }
    end
  end

  private
    # Use callbacks to share common setup or constraints between actions.
    def set_writing
      @writing = Writing.find_by_slug!(params[:slug])
    end

    # Only allow a list of trusted parameters through.
    def writing_params
      params.require(:writing).permit(:title, :content, :status, :published_at, :excerpt, :featured_image, downloadable_files: [])
    end

    def require_staff_and_admin
      unless Current.user&.is_staff? && Current.user&.is_admin?
        redirect_to writings_path, alert: "You must be both staff and admin to perform this action."
      end
    end
end
