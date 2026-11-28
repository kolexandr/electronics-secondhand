class ListingsController < ApplicationController
  allow_unauthenticated_access only: %i[index show]
  before_action :set_owned_listing, only: %i[edit update destroy]
  before_action :set_categories, only: %i[index new create edit update]

  def index
    @filters = params.permit(:q, :category_id, :condition, :min_price, :max_price, :sort).to_h
    scope = Listing.available.includes(:seller, :category).with_attached_photo
    if @filters["q"].present?
      query = "%#{Listing.sanitize_sql_like(@filters["q"].strip)}%"
      scope = scope.where("title LIKE :query OR description LIKE :query", query: query)
    end
    scope = scope.where(category_id: @filters["category_id"]) if @filters["category_id"].present?
    scope = scope.where(condition: @filters["condition"]) if @filters["condition"].present?
    @filter_errors = []
    %w[min_price max_price].each do |key|
      next if @filters[key].blank?
      cents = Listing.cents_from(@filters[key])
      if cents
        scope = key == "min_price" ? scope.where("price_cents >= ?", cents) : scope.where("price_cents <= ?", cents)
      else
        @filter_errors << "#{key.humanize} must be a valid euro amount."
        scope = scope.none
      end
    end
    order = case @filters["sort"]
    when "price_low" then { price_cents: :asc, id: :desc }
    when "price_high" then { price_cents: :desc, id: :desc }
    when "oldest" then { created_at: :asc, id: :asc }
    else { created_at: :desc, id: :desc }
    end
    paginate(scope.order(order))
  end

  def show
    @listing = Listing.includes(:seller, :category).with_attached_photo.find(params[:id])
    @active_reservation = @listing.reservations.active.first
  end

  def mine
    paginate(Current.user.listings.includes(:seller, :category).with_attached_photo.order(created_at: :desc, id: :desc))
  end

  def new
    @listing = Current.user.listings.build
  end

  def create
    @listing = Current.user.listings.build(listing_params)
    if @listing.save
      redirect_to @listing, notice: "Your listing is live."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    redirect_to @listing, alert: "Only available listings can be edited." unless @listing.available?
  end

  def update
    @listing.with_lock do
      unless @listing.available?
        redirect_to @listing, alert: "Only available listings can be edited."
        return
      end
      if @listing.update(listing_params)
        redirect_to @listing, notice: "Listing updated."
      else
        render :edit, status: :unprocessable_entity
      end
    end
  end

  def destroy
    @listing.with_lock do
      if @listing.destroy
        redirect_to mine_listings_path, notice: "Listing removed.", status: :see_other
      else
        redirect_to @listing, alert: @listing.errors.full_messages.to_sentence, status: :see_other
      end
    end
  end

  private
    def set_owned_listing
      @listing = Current.user.listings.find(params[:id])
    end

    def set_categories
      @categories = Category.order(:name)
    end

    def listing_params
      permitted = params.expect(listing: [ :title, :description, :category_id, :condition, :price, :photo ])
      permitted.delete(:photo) if permitted[:photo].blank?
      if permitted[:photo] && !permitted[:photo].is_a?(ActionDispatch::Http::UploadedFile)
        raise ActionController::BadRequest, "Photo must be an uploaded file"
      end
      permitted
    end

    def paginate(scope)
      @total = scope.count
      @pages = [ (@total / 12.0).ceil, 1 ].max
      @page = params[:page].to_i.clamp(1, @pages)
      @listings = scope.limit(12).offset((@page - 1) * 12)
    end
end
