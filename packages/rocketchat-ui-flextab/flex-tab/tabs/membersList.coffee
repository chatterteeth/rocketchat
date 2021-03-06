Template.membersList.helpers
	tAddUsers: ->
		return t('Add_users')

	isGroupChat: ->
		return ChatRoom.findOne(this.rid, { reactive: false })?.t in ['c', 'p']

	isDirectChat: ->
		return ChatRoom.findOne(this.rid, { reactive: false })?.t is 'd'

	seeAll: ->
		if Template.instance().showAllUsers.get()
			return t('Show_only_online')
		else
			return t('Show_all')

	roomUsers: ->
		users = []
		onlineUsers = RoomManager.onlineUsers.get()
		roomUsernames = ChatRoom.findOne(this.rid)?.usernames or []

		for username in roomUsernames
			if Template.instance().showAllUsers.get() or onlineUsers[username]?
				utcOffset = onlineUsers[username]?.utcOffset
				if utcOffset?
					if utcOffset > 0
						utcOffset = "+#{utcOffset}"

					utcOffset = "(UTC #{utcOffset})"

				users.push
					username: username
					status: onlineUsers[username]?.status
					utcOffset: utcOffset

		users = _.sortBy users, 'username'
		# show online users first.
		# sortBy is stable, so we can do this
		users = _.sortBy users, (u) -> !u.status?

		hasMore = users.length > Template.instance().usersLimit.get()

		users = _.first(users, Template.instance().usersLimit.get())

		totalUsers = roomUsernames.length
		totalShowing = users.length

		ret =
			_id: this.rid
			total: totalUsers
			totalShowing: totalShowing
			users: users
			hasMore: hasMore

		return ret

	canAddUser: ->
		roomData = Session.get('roomData' + this._id)
		return '' unless roomData
		return roomData.t in ['p', 'c'] and RocketChat.authz.hasAllPermission('add-user-to-room', this._id)

	autocompleteSettingsAddUser: ->
		return {
			limit: 10
			# inputDelay: 300
			rules: [
				{
					collection: 'UserAndRoom'
					subscription: 'userAutocomplete'
					field: 'username'
					template: Template.userSearch
					noMatchTemplate: Template.userSearchEmpty
					matchAll: true
					filter:
						exceptions: [Meteor.user().username]
					selector: (match) ->
						return { username: match }
					sort: 'username'
				}
			]
		}

	showUserInfo: ->
		webrtc = WebRTC.getInstanceByRoomId(this.rid)
		videoActive = webrtc?.localUrl?.get()? or webrtc?.remoteItems?.get()?.length > 0
		return Template.instance().showDetail.get() and not videoActive

	userInfoDetail: ->
		room = ChatRoom.findOne(this.rid, { fields: { t: 1 } })

		return {
			username: Template.instance().userDetail.get()
			clear: Template.instance().clearUserDetail
			showAll: room?.t in ['c', 'p']
			video: room?.t in ['d']
		}

Template.membersList.events
	'click .see-all': (e, instance) ->
		seeAll = instance.showAllUsers.get()
		instance.showAllUsers.set(!seeAll)

		if not seeAll
			instance.usersLimit.set 100

	'autocompleteselect #user-add-search': (event, template, doc) ->

		roomData = Session.get('roomData' + template.data.rid)

		if roomData.t is 'd'
			Meteor.call 'createGroupRoom', roomData.usernames, doc.username, (error, result) ->
				if error
					return toastr.error error.reason

				if result?.rid?
					$('#user-add-search').val('')
		else if roomData.t in ['c', 'p']
			Meteor.call 'addUserToRoom', { rid: roomData._id, username: doc.username }, (error, result) ->
				if error
					return toastr.error error.reason

				$('#user-add-search').val('')

	'click .show-more-users': (e, instance) ->
		instance.usersLimit.set(instance.usersLimit.get() + 100)

Template.membersList.onCreated ->
	@showAllUsers = new ReactiveVar false
	@usersLimit = new ReactiveVar 100
	@userDetail = new ReactiveVar
	@showDetail = new ReactiveVar false

	@clearUserDetail = =>
		@showDetail.set(false)
		setTimeout =>
			@clearRoomUserDetail()
		, 500

	@showUserDetail = (username) =>
		@showDetail.set(username?)
		@userDetail.set(username)

	@clearRoomUserDetail = @data.clearUserDetail

	@autorun =>
		data = Template.currentData()
		@showUserDetail data.userDetail
