// This file is part of MusicBrainz, the open internet music database.
// Copyright (C) 2016 MetaBrainz Foundation
// Licensed under the GPL version 2, or (at your option) any later version:
// http://www.gnu.org/licenses/gpl-2.0.txt

const Immutable = require('immutable');
const $ = require('jquery');
const ko = require('knockout');
const _ = require('lodash');
const React = require('react');
const ReactDOM = require('react-dom');

const Frag = require('../../../../components/Frag');
const Autocomplete = require('../../common/components/Autocomplete');
const {l} = require('../../common/i18n');
const {
    ArtistCredit,
    artistCreditFromArray,
    ArtistCreditName,
    artistCreditsAreEqual,
    hasArtist,
    hasVariousArtists,
    isCompleteArtistCredit,
    isComplexArtistCredit,
    reduceArtistCredit,
  } = require('../../common/immutable-entities');
const nonEmpty = require('../../common/utility/nonEmpty');
const ArtistCreditBubble = require('./ArtistCreditBubble');

function stateFromArray(names) {
  return {artistCredit: artistCreditFromArray(names)};
}

function setAutoJoinPhrases(names) {
  const size = names.size;
  const auto = /^(| & |, )$/;

  if (size > 0) {
    const name0 = names.get(size - 1);
    if (name0 && name0.automaticJoinPhrase) {
      names = names.mergeIn([size - 1], {joinPhrase: ''});
    }
  }

  if (size > 1) {
    const name1 = names.get(size - 2);
    if (name1 && name1.automaticJoinPhrase && auto.test(name1.joinPhrase)) {
      names = names.mergeIn([size - 2], {joinPhrase: ' & '});
    }
  }

  if (size > 2) {
    const name2 = names.get(size - 3);
    if (name2 && name2.automaticJoinPhrase && auto.test(name2.joinPhrase)) {
      names = names.mergeIn([size - 3], {joinPhrase: ', '});
    }
  }

  return names;
}

const makeHiddenInput = (data) => (
  <input
    key={data.name}
    name={data.name}
    type="hidden"
    value={nonEmpty(data.value) ? data.value : ''}
  />
);

class ArtistCreditEditor extends React.Component {
  constructor(props) {
    super(props);

    this.state = {
      artistCredit: ko.unwrap(this.props.entity.artistCredit)
    };

    this.addName = this.addName.bind(this);
    this.copyArtistCredit = this.copyArtistCredit.bind(this);
    this.done = this.done.bind(this);
    this.hide = this.hide.bind(this);
    this.onNameChange = this.onNameChange.bind(this);
    this.pasteArtistCredit = this.pasteArtistCredit.bind(this);
    this.removeName = this.removeName.bind(this);
    this.toggleBubble = this.toggleBubble.bind(this);
  }

  addName() {
    this.setState({
      artistCredit: this.state.artistCredit.update(
        'names',
        names => setAutoJoinPhrases(names.push(new ArtistCreditName())),
      )
    }, () => this.positionBubble());
  }

  removeName(index, event) {
    // Prevent track artist bubbles from closing.
    event.stopPropagation();

    const ac = this.state.artistCredit;
    const newAC = ac.update('names', names => setAutoJoinPhrases(names.delete(index)));

    this.setState({artistCredit: newAC}, () => {
      this.positionBubble();
      if (index > 0 && index === ac.names.size - 1) {
        $('#artist-credit-bubble').find('.remove-item').eq(index - 1).focus();
      }
    });
  }

  onNameChange(index, update) {
    this.setState({
      artistCredit: this.state.artistCredit.mergeIn(['names', index], update)
    });
  }

  copyArtistCredit() {
    let names = this.state.artistCredit.names;

    if (!names.size) {
      names = names.push(new ArtistCreditName());
    }

    MB.localStorage('copiedArtistCredit', JSON.stringify(names.toJSON()));
  }

  pasteArtistCredit() {
    const names = JSON.parse(MB.localStorage('copiedArtistCredit') || '[{}]');
    this.setState(stateFromArray(names));
  }

  toggleBubble() {
    const $bubble = $('#artist-credit-bubble');
    if ($bubble.is(':visible')) {
      const inst = $bubble.data('componentInst');

      if (inst.props.doneCallback) {
        inst.props.doneCallback();
      }

      if ($bubble.data('target') === this.props.entity) {
        this.hide();
        return;
      }
    }
    this.updateBubble(true);
  }

  positionBubble() {
    const $bubble = $('#artist-credit-bubble');
    if (!$bubble.length) {
      return;
    }

    const $button = $(this._editButton);
    let position = {of: $button[0], collision: 'fit none', within: $('body')};
    let maxWidth;
    let tailClass;

    if (this.props.orientation === 'left') {
      position.my = 'right center';
      position.at = 'left-15 center';
      maxWidth = $button.position().left - 64;
      tailClass = 'right-tail';
    } else {
      position.my = 'left center';
      position.at = 'right+15 center';
      maxWidth = $('body').innerWidth() - ($button.position().left + $button.outerWidth() + 64);
      tailClass = 'left-tail';
    }

    $bubble
      .css('max-width', maxWidth)
      .data('target', this.props.entity)
      .data('componentInst', this)
      .find('.bubble')
        .removeClass('left-tail right-tail')
        .addClass(tailClass)
        .end()
      .show()
      .position(position)
      // For some reason this needs to be called twice...
      // Steps to reproduce: open the release AC bubble, switch to the
      // tracklist tab, open a track AC bubble.
      .position(position);
  }

  updateBubble(show = false) {
    this.createBubble();

    const $bubble = $('#artist-credit-bubble');
    const bubbleWasVisible = $bubble.is(':visible');

    // `show` implies the bubble should be made visible with a new entity. If
    // show = false and the bubble isn't visible, there's no point in updating it.
    if (!show && !bubbleWasVisible) {
      return;
    }

    // Don't hijack the bubble unless show = true or this is for the
    // currently-open entity.
    if (!show && $bubble.data('target') !== this.props.entity) {
      return;
    }

    const props = this.props;
    if (show && props.beforeShow) {
      props.beforeShow(props, this.state);
    }

    ReactDOM.render(
      <ArtistCreditBubble
        addName={this.addName}
        artistCredit={this.state.artistCredit}
        copyArtistCredit={this.copyArtistCredit}
        done={this.done}
        hide={this.hide}
        onNameChange={this.onNameChange}
        pasteArtistCredit={this.pasteArtistCredit}
        removeName={this.removeName}
        {...props}
      />,
      $bubble[0],
      show ? (() => {
        this.positionBubble();

        if (!bubbleWasVisible) {
          $bubble.find(':input:eq(0)').focus();
        }
      }) : null,
    );
  }

  hide(stealFocus = true) {
    const $bubble = $('#artist-credit-bubble').hide();
    if (stealFocus) {
      this._editButton.focus();
    }
    // Defer until after the doneCallback() executes (if done() called us).
    _.defer(function () {
      $bubble.data('target', null).data('componentInst', null);
    });
  }

  done(stealFocus = true, nextTrack = false) {
    if (this.props.doneCallback) {
      this.props.doneCallback();
    }

    // XXX The release editor still uses knockout.
    if (nextTrack) {
      const entity = this.props.entity;
      if (entity.entityType === 'track') {
        const next = entity.medium.tracks()[entity.position()];
        if (next) {
          ko.bindingHandlers.artistCreditEditor.nextTrack();
          return;
        }
      }
    }

    this.hide(stealFocus);
  }

  createBubble() {
    if (!document.getElementById('artist-credit-bubble')) {
      const $bubble = $('<div id="artist-credit-bubble"></div>')
        .hide()
        .appendTo('body');

      $('body').on('click.artist-credit-editor', event => {
        const $target = $(event.target);
        if (!event.isDefaultPrevented() &&
            $bubble.is(':visible') &&
            $target.is(':not(.open-ac)') &&
            !$bubble.has($target).length &&
            // Close unless focus was moved to a dialog above this one, e.g.
            // when adding a new entity.
            !$target.parents('.ui-dialog').length) {
          $bubble.data('componentInst').done(false);
        }
      });
    }
  }

  componentWillUnmount() {
    $('body').off('click.artist-credit-editor');
  }

  componentWillReceiveProps(nextProps) {
    const artistCredit = ko.unwrap(nextProps.entity.artistCredit);
    if (!artistCreditsAreEqual(this.state.artistCredit, artistCredit)) {
      this.setState({artistCredit});
    }
  }

  componentWillUpdate(nextProps, nextState) {
    if (nextProps.onChange &&
        !artistCreditsAreEqual(this.state.artistCredit, nextState.artistCredit)) {
      nextProps.onChange(nextState.artistCredit);
    }
  }

  componentDidUpdate() {
    this.updateBubble();
    $('div.various-artists.warning')
      .toggle(hasVariousArtists(this.state.artistCredit));
  }

  getHiddenInputs() {
    let prefix = 'artist_credit.names.';

    if (this.props.form) {
      prefix = this.props.form.name + '.' + prefix;
    }

    return _.flatten(_.map(this.state.artistCredit.names.toJS(), function (name, index) {
      const curPrefix = prefix + index + '.';

      return [
        {name: curPrefix + 'name', value: name.name},
        {name: curPrefix + 'join_phrase', value: name.joinPhrase},
        {name: curPrefix + 'artist.name', value: name.artist ? name.artist.name : ''},
        {name: curPrefix + 'artist.id', value: name.artist ? name.artist.id : ''},
      ];
    }));
  }

  render() {
    const ac = this.state.artistCredit;
    const names = ac.names;
    let entity = _.clone(this.props.entity);
    entity.artistCredit = names.filter(n => hasArtist(n)).toJS();

    // The single-artist lookup changes the credit boxes in the doc bubble,
    // and the credit boxes change the single-artist lookup.
    const complex = isComplexArtistCredit(ac);
    let singleArtistSelection = {name: ''};
    let singleArtistIsEditable = true;

    if (complex || names.size > 1) {
      singleArtistSelection.name = reduceArtistCredit(ac);
      singleArtistIsEditable = false;
    } else {
      const firstName = names.get(0);
      if (firstName) {
        if (hasArtist(firstName)) {
          singleArtistSelection = firstName.artist;
        } else {
          singleArtistSelection.name = firstName.name;
        }
      }
    }

    return (
      <Frag>
        <table key="artist-credit-editor" className="artist-credit-editor">
          <tbody>
            <tr>
              <td>
                <Autocomplete
                  currentSelection={singleArtistSelection}
                  disabled={!singleArtistIsEditable}
                  entity="artist"
                  inputID={this.props.forLabel}
                  isLookupPerformed={isCompleteArtistCredit(ac)}
                  onChange={artist => {
                    if (singleArtistIsEditable) {
                      this.setState({
                        artistCredit: new ArtistCredit({
                          names: Immutable.List([
                            new ArtistCreditName({
                              artist,
                              name: artist.name,
                              joinPhrase: '',
                            })
                          ])
                        })
                      });
                    }
                  }}
                  showStatus={false} />
              </td>
              <td className="open-ac-cell">
                <button
                  className="open-ac"
                  ref={button => this._editButton = button}
                  type="button"
                  onClick={this.toggleBubble}>
                  {l('Edit')}
                </button>
              </td>
            </tr>
          </tbody>
        </table>
        {this.props.hiddenInputs
          ? this.getHiddenInputs().map(makeHiddenInput)
          : null}
      </Frag>
    );
  }
}

module.exports = ArtistCreditEditor;
