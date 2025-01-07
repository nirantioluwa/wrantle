class ContactsController < ApplicationController
  allow_unauthenticated_access only: %i[ new create show ]
  before_action :set_contact, only: %i[ show edit update destroy ]
  # Rate limit to 3 submissions per hour per IP
  rate_limit to: 3, within: 1.hour, only: :create, with: -> { redirect_to root_path, alert: "We already received 3 messages from you. Trust us, we will get back to you." }

  # GET /contacts or /contacts.json
  def index
    @contacts = Contact.all
  end

  # GET /contacts/1 or /contacts/1.json
  def show
  end

  # GET /contacts/new
  def new
    @contact = Contact.new(contact_type: params[:contact_type])
  end

  # GET /contacts/1/edit
  def edit
  end

  # POST /contacts or /contacts.json
  def create
    @contact = Contact.new(contact_params)

    if @contact.save
      # Send confirmation email to user
      ContactMailer.confirmation_email(@contact).deliver_later

      # Send notification email to admin
      ContactMailer.notification_email(@contact).deliver_later

      redirect_to @contact, notice: "Thank you! Your message has been submitted successfully. We'll be in touch soon!"
    else
      render :new, status: :unprocessable_entity
    end
  end

  # PATCH/PUT /contacts/1 or /contacts/1.json
  def update
    respond_to do |format|
      if @contact.update(contact_params)
        format.html { redirect_to @contact, notice: "Contact was successfully updated." }
        format.json { render :show, status: :ok, location: @contact }
      else
        format.html { render :edit, status: :unprocessable_entity }
        format.json { render json: @contact.errors, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /contacts/1 or /contacts/1.json
  def destroy
    @contact.destroy!

    respond_to do |format|
      format.html { redirect_to contacts_path, status: :see_other, notice: "Contact was successfully destroyed." }
      format.json { head :no_content }
    end
  end

  private
    # Use callbacks to share common setup or constraints between actions.
    def set_contact
      @contact = Contact.find(params[:id])
    end

    # Only allow a list of trusted parameters through.
    def contact_params
      params.require(:contact).permit(:name, :email, :phone, :contact_type, :message, :preferred_date, :preferred_time, :status, :website)
    end
end
