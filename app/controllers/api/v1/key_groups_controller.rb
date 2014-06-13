module Api
  module V1
    class KeyGroupsController < ApplicationController
      respond_to :json

      skip_before_action :verify_authenticity_token
      before_filter :authenticate_and_find_project
      before_filter :find_key_group, only: [:show, :update, :status, :manifest]

      def index
        render json: decorate_key_groups(@project.key_groups)
      end

      def create
        key_group = @project.key_groups.for_key(params[:key].to_s).create(params.permit(:key, :source_copy, :description, :email, :base_rfc5646_locale, :targeted_rfc5646_locales))
        if key_group.errors.blank?
          render json: decorate_key_group(key_group), status: :accepted
        else
          render json: { error: { errors: key_group.errors } }, status: :bad_request
        end
      end

      def show
        render json: decorate_key_group(@key_group), status: :ok
      end

      def update
        # TODO: what if TRYING TO UPDATE BEFORE THE PREVIOUS RUN IS FINISHED
        key_group = @key_group.update(params.permit(:source_copy, :description, :email, :targeted_rfc5646_locales))
        if key_group.errors.blank?
          render json: decorate_key_group(key_group), status: :accepted
        else
          render json: { error: { errors: key_group.errors } }, status: :bad_request
        end
      end

      def status
        render json: decorate_key_group_status(@key_group)
      end

      def manifest
        begin
          render json: Exporter::KeyGroup.new(@key_group).export
        rescue Exporter::KeyGroup::Error => e
          render json: { error: { errors: [{ message: e.inspect }] } }, status: :bad_request
        end
      end

      private

      def authenticate_and_find_project
        unless @project = Project.find_by_api_key(params[:api_key])
          render json: { error: { errors: [{ message: "Invalid project API KEY" }] } }, status: :unauthorized
        end
      end

      def find_key_group
        unless @key_group = @project.key_groups.find_by_key(params[:key])
          render json: { error: { errors: [{ message: "Key group doesn't exist" }] } }, status: :not_found
        end
      end

      # ====== START DECORATORS =======
      def decorate_key_groups(key_groups)
        key_groups.map do |key_group|
          {
            key: key_group.key,
            ready: key_group.ready,
            last_import_finished_at: key_group.last_import_finished_at
          }
        end
      end

      def decorate_key_group(key_group)
        [
         :key, :project_id, :source_copy, :ready, :loading, :description, :email,
         :base_rfc5646_locale, :targeted_rfc5646_locales,
         :first_import_requested_at, :last_import_requested_at,
         :first_import_started_at, :last_import_started_at,
         :first_import_finished_at, :last_import_finished_at,
         :first_completed_at, :last_completed_at,
         :created_at, :updated_at
        ].inject({}) do |hsh, field|
          hsh[field] = key_group.send(field)
          hsh
        end
      end

      def decorate_key_group_status(key_group)
        {
          ready: key_group.ready,
          last_import_requested_at: key_group.last_import_requested_at,
          last_import_started_at: key_group.last_import_started_at,
          last_import_finished_at: key_group.last_import_finished_at,
          last_completed_at: key_group.last_completed_at
        }
      end
      # ====== END DECORATORS =======
    end
  end
end
