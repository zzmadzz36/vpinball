/*
 * This code was derived from notes at:
 *
 * https://nailbuster.com/pup/PUPDMD_Reference_v13.zip
 */

#include "core/stdafx.h"

#include "PUPLabel.h"
#include "PUPScreen.h"
#include "PUPPlaylist.h"
#include "PUPManager.h"

#include "RSJparser/RSJparser.tcc"

PUPLabel::PUPLabel(const string& szName, const string& szFont, float size, LONG color, float angle, PUP_LABEL_XALIGN xAlign, PUP_LABEL_YALIGN yAlign, float xPos, float yPos, int pagenum, bool visible)
{
   m_szName = szName;
   m_pFont = PUPManager::GetInstance()->GetFont(szFont);
   m_size = size;
   m_color = color;
   m_angle = angle;
   m_xAlign = xAlign;
   m_yAlign = yAlign;
   m_xPos = xPos;
   m_yPos = yPos;
   m_visible = visible;
   m_pagenum = pagenum;
   m_shadowColor = 0;
   m_shadowState = 0;
   m_xoffset = 0;
   m_yoffset = 0;
   m_outline = false;
   m_dirty = true;
   m_pScreen = nullptr;
   m_pTexture = NULL;
   m_width = 0;
   m_height = 0;
   m_anigif = 0;
   m_pAnimation = NULL;
}

PUPLabel::~PUPLabel()
{
   if (m_pTexture)
      SDL_DestroyTexture(m_pTexture);
}

void PUPLabel::SetCaption(const string& szCaption)
{
   if (szCaption == "`u`")
      return;

   string szText = szCaption;
   std::replace(szText.begin(), szText.end(), '~', '\n');

   if (m_szCaption != szText) {
      m_type = PUP_LABEL_TYPE_TEXT;
      m_szPath.clear();

      const string szExt = extension_from_path(szCaption);
      if (szExt == "gif"s || szExt == "png"s || szExt == "apng"s || szExt == "bmp"s || szExt == "jpg"s) {
         std::filesystem::path fs_path(normalize_path_separators(szCaption));
         PUPPlaylist* pPlaylist = PUPManager::GetInstance()->GetPlaylist(fs_path.parent_path());
         if (pPlaylist) {
            m_szPath = find_path_case_insensitive(pPlaylist->GetFolderPath() + fs_path.filename().string());
            if (!m_szPath.empty())
               m_type = (szExt == "gif"s) ? PUP_LABEL_TYPE_GIF : PUP_LABEL_TYPE_IMAGE;
         }
      }

      m_szCaption = szText;
      m_dirty = true;
   }
}

void PUPLabel::SetSpecial(const string& szSpecial)
{
   PLOGD.printf("PUPLabel::SetSpecial: name=%s, caption=%s, json=%s", m_szName.c_str(), m_szCaption.c_str(), szSpecial.c_str());

   RSJresource json(szSpecial);
   switch (json["mt"s].as<int>(0)) {
      case 2: {
         if (json["zback"s].exists() && json["zback"s].as<int>() == 1)
            m_pScreen->SendLabelToBack(this);

         if (json["ztop"s].exists() && json["ztop"s].as<int>() == 1)
            m_pScreen->SendLabelToFront(this);

         if (json["size"s].exists()) {
            m_size = std::stof(json["size"s].as_str());
            m_dirty = true;
         }

         if (json["xpos"s].exists()) {
            m_xPos = std::stof(json["xpos"s].as_str());
            m_dirty = true;
         }

         if (json["ypos"s].exists()) {
            m_yPos = std::stof(json["ypos"s].as_str());
            m_dirty = true;
         }

         if (json["fname"s].exists()) {
            m_pFont = PUPManager::GetInstance()->GetFont(json["fname"s].as_str());
            m_dirty = true;
         }

         if (json["color"s].exists()) {
            m_color = json["color"s].as<int>();
            m_dirty = true;
         }

         if (json["xalign"s].exists()) {
            m_xAlign = (PUP_LABEL_XALIGN)json["xalign"s].as<int>();
            m_dirty = true;
         }

         if (json["yalign"s].exists()) {
            m_yAlign = (PUP_LABEL_YALIGN)json["yalign"s].as<int>();
            m_dirty = true;
         }

         if (json["pagenum"s].exists()) {
            m_pagenum = json["pagenum"s].as<int>();
            m_dirty = true;
         }

         if (json["stopani"s].exists()) {
            // stop any pup animations on label/image (zoom/flash/pulse).  this is not about animated gifs
            PLOGW.printf("stopani not implemented");
            m_dirty = true;
         }

         if (json["rotate"s].exists()) {
            // in tenths.  so 900 is 90 degrees. rotate support for images too.  note images must be aligned center to rotate properly(default)
            m_angle = std::stof(json["rotate"s].as_str());
            m_dirty = true;
         }

         if (json["zoom"s].exists()) {
            // 120 for 120% of current height, 80% etc...
            PLOGW.printf("zoom not implemented");
            m_dirty = true;
         }

         if (json["alpha"s].exists()) {
            // '0-255  255=full, 0=blank
            PLOGW.printf("alpha not implemented");
            m_dirty = true;
         }

         if (json["gradstate"s].exists() && json["gradcolor"s].exists()) {
            // color=gradcolor, gradstate = 0 (gradstate is percent)
            PLOGW.printf("gradstate/gradcolor not implemented");
            m_dirty = true;
         }

         if (json["grayscale"s].exists()) {
            // only on image objects.  will show as grayscale.  1=gray filter on 0=off normal mode
            PLOGW.printf("filter not implemented");
            m_dirty = true;
         }

         if (json["filter"s].exists()) {
            // fmode 1-5 (invertRGB, invert,grayscale,invertalpha,clear),blur)
            PLOGW.printf("filter not implemented");
            m_dirty = true;
         }

         if (json["shadowcolor"s].exists()) {
            m_shadowColor = json["shadowcolor"s].as<int>();
            m_dirty = true;
         }

         if (json["shadowtype"s].exists()) {
            // ST = 1 (Shadow), ST = 2 (Border)
            PLOGW.printf("shadowtype not implemented");
            m_dirty = true;
         }

         if (json["xoffset"s].exists()) {
            m_xoffset = std::stof(json["xoffset"s].as_str());
            m_dirty = true;
         }

         if (json["yoffset"s].exists()) {
            m_yoffset = std::stof(json["yoffset"s].as_str());
            m_dirty = true;
         }

         if (json["anigif"s].exists()) {
            m_anigif = json["anigif"s].as<int>();
            m_dirty = true;
         }

         if (json["width"s].exists()) {
            m_width = std::stof(json["width"s].as_str());
            m_dirty = true;
         }

         if (json["height"s].exists()) {
            m_height = std::stof(json["height"s].as_str());
            m_dirty = true;
         }

          if (json["autow"s].exists()) {
            PLOGW.printf("autow not implemented");
            m_dirty = true;
         }

         if (json["autoh"s].exists()) {
            PLOGW.printf("autoh not implemented");
            m_dirty = true;
         }

         if (json["shadowstate"s].exists()) {
            m_shadowState = json["shadowstate"s].as<int>();
            m_dirty = true;
         }

         if (json["outline"s].exists()) {
            m_outline = (json["outline"s].as<int>() == 1);
            m_dirty = true;
         }
      }
      break;

      case 1: {
         /*
            Animate
            at = animate type (1=flashing, 2=motion)
            fq = when flashing its the frequency of flashing
            len = length in ms of animation
            fc = foreground color of text during animation
            PLOGW << "Label animation not implemented";
         */
      }
      break;

      default: break;
   }
}

void PUPLabel::Render(SDL_Renderer* pRenderer, SDL_Rect& rect, int pagenum)
{
   if (!m_visible || pagenum != m_pagenum || m_szCaption.empty())
      return;

   if (m_dirty) {
      if (!m_szPath.empty()) {
         if (m_pAnimation)
            IMG_FreeAnimation(m_pAnimation);
         m_pAnimation = IMG_LoadAnimation(m_szPath.c_str());
         if (m_pAnimation) {
            m_frame = 0;
            m_pTexture = SDL_CreateTextureFromSurface(pRenderer, m_pAnimation->frames[m_frame]);
            m_dirty = false;
         }
      }
      else {
         if (m_pFont)
            UpdateLabelTexture(pRenderer, rect);
      }
   }

   if (!m_pTexture) {
      PLOGW.printf("Unable to render label: caption=%s", m_szCaption.c_str());
      return;
   }

   if (m_pAnimation) {
      if (++m_frame >= m_pAnimation->count)
         m_frame = 0;
      SDL_UpdateTexture(m_pTexture, nullptr, m_pAnimation->frames[m_frame]->pixels, m_pAnimation->frames[m_frame]->pitch);
   }

   float width;
   float height;

   if (m_pAnimation) {
      width = (m_width / 100.0) * rect.w;
      height = (m_height / 100.0) * rect.h;
   }
   else {
      width = m_width;
      height = m_height;
   }

   SDL_FRect dest = { (float)rect.x, (float)rect.y, width, height };

   if (m_xPos > 0) {
      dest.x += ((m_xPos / 100.0) * rect.w);
      if (m_xAlign == PUP_LABEL_XALIGN_CENTER)
         dest.x -= (width / 2);
      else if (m_xAlign == PUP_LABEL_XALIGN_RIGHT)
         dest.x -= width;
   }
   else {
      if (m_xAlign == PUP_LABEL_XALIGN_CENTER)
         dest.x += ((rect.w - width) / 2);
      else if (m_xAlign == PUP_LABEL_XALIGN_RIGHT)
         dest.x += (rect.w - width);
   }

   if (m_yPos > 0) {
      dest.y += ((m_yPos / 100.0) * rect.h);
      if (m_yAlign == PUP_LABEL_YALIGN_CENTER)
         dest.y -= (height / 2);
      else if (m_yAlign == PUP_LABEL_YALIGN_BOTTOM)
         dest.y -= height;
   }
   else {
      if (m_yAlign == PUP_LABEL_YALIGN_CENTER)
         dest.y += ((rect.h - height) / 2.0);
      else if (m_yAlign == PUP_LABEL_YALIGN_BOTTOM)
         dest.y += (rect.h - height);
   }

   SDL_FPoint center = { height / 2.0f, 0 };
   SDL_RenderCopyExF(pRenderer, m_pTexture, NULL, &dest, -m_angle / 10.0, &center, SDL_FLIP_NONE);
}

void PUPLabel::UpdateLabelTexture(SDL_Renderer* pRenderer, SDL_Rect& rect)
{
   if (m_pTexture) {
      SDL_DestroyTexture(m_pTexture);
      m_pTexture = NULL;
   }

   int height = (int)((m_size / 100.0) * rect.h);
   TTF_SetFontSize(m_pFont, height);
   TTF_SetFontOutline(m_pFont, 0);

   SDL_Color textColor = { GetRValue(m_color), GetGValue(m_color), GetBValue(m_color) };
   SDL_Surface* pTextSurface = TTF_RenderUTF8_Blended(m_pFont, m_szCaption.c_str(), textColor);
   if (!pTextSurface)
      return;

   SDL_Surface* pMergedSurface = NULL;

   if (m_shadowState) {
      SDL_Color shadowColor = { GetRValue(m_shadowColor), GetGValue(m_shadowColor), GetBValue(m_shadowColor) };
      SDL_Surface* pShadowSurface = TTF_RenderUTF8_Blended(m_pFont, m_szCaption.c_str(), shadowColor);
      if (!pShadowSurface) {
         delete pTextSurface;
         return;
      }

      int xoffset = (int) (((abs(m_xoffset) / 100.0) * height) / 2);
      int yoffset = (int) (((abs(m_yoffset) / 100.0) * height) / 2);

      pMergedSurface = SDL_CreateRGBSurfaceWithFormat(0, pTextSurface->w + xoffset, pTextSurface->h + yoffset, 32, SDL_PIXELFORMAT_RGBA32);
      if (pMergedSurface) {
         //SDL_FillRect(pMergedSurface, NULL, SDL_MapRGBA(pMergedSurface->format, 255, 255, 0, 255));
         if (!m_outline) {
            SDL_Rect shadowRect = { (m_xoffset < 0) ? 0 : xoffset, (m_yoffset < 0) ? 0 : yoffset, pShadowSurface->w, pShadowSurface->h };
            SDL_BlitSurface(pShadowSurface, NULL, pMergedSurface, &shadowRect);

            SDL_Rect textRect = { (m_xoffset > 0) ? 0 : xoffset, (m_yoffset > 0) ? 0 : yoffset, pTextSurface->w, pTextSurface->h };
            SDL_BlitSurface(pTextSurface, NULL, pMergedSurface, &textRect);
         }
         else {
            SDL_Rect shadowRects[8] = {
               { 0,           0,           pShadowSurface->w, pShadowSurface->h },
               { xoffset / 2, 0,           pShadowSurface->w, pShadowSurface->h },
               { xoffset,     0,           pShadowSurface->w, pShadowSurface->h },

               { 0,           yoffset / 2, pShadowSurface->w, pShadowSurface->h },
               { xoffset,     yoffset / 2, pShadowSurface->w, pShadowSurface->h },

               { 0,           yoffset,     pShadowSurface->w, pShadowSurface->h },
               { xoffset / 2, yoffset,     pShadowSurface->w, pShadowSurface->h },
               { xoffset,     yoffset,     pShadowSurface->w, pShadowSurface->h }
            };

            for (int i = 0; i < 8; ++i)
               SDL_BlitSurface(pShadowSurface, NULL, pMergedSurface, &shadowRects[i]);

            SDL_Rect textRect = { xoffset / 2, yoffset / 2, pTextSurface->w, pTextSurface->h };
            SDL_BlitSurface(pTextSurface, NULL, pMergedSurface, &textRect);
         }
      }

      SDL_FreeSurface(pShadowSurface);
   }
   else {
      pMergedSurface = SDL_CreateRGBSurfaceWithFormat(0, pTextSurface->w, pTextSurface->h, 32, SDL_PIXELFORMAT_RGBA32);
      if (pMergedSurface) {
         //SDL_FillRect(pMergedSurface, NULL, SDL_MapRGBA(pMergedSurface->format, 255, 255, 0, 255));
         SDL_BlitSurface(pTextSurface, NULL, pMergedSurface, NULL);
      }
   }

   if (pMergedSurface) {
      m_pTexture = SDL_CreateTextureFromSurface(pRenderer, pMergedSurface);
      if (m_pTexture) {
         m_width = pMergedSurface->w;
         m_height = pMergedSurface->h;

         m_dirty = true;
      }

      SDL_FreeSurface(pMergedSurface);
   }

   SDL_FreeSurface(pTextSurface);
}

string PUPLabel::ToString() const
{
   return "name=" + m_szName +
      ", caption=" + m_szCaption +
      ", visible=" + (m_visible ? "true" : "false") +
      ", size=" + std::to_string(m_size) +
      ", color=" + std::to_string(m_color) +
      ", angle=" + std::to_string(m_angle) +
      ", xAlign=" + (m_xAlign == PUP_LABEL_XALIGN_LEFT  ? "LEFT" : m_xAlign == PUP_LABEL_XALIGN_CENTER ? "CENTER" : "RIGHT") +
      ", yAlign=" + (m_yAlign == PUP_LABEL_YALIGN_TOP ? "TOP" : m_yAlign == PUP_LABEL_YALIGN_CENTER ? "CENTER" : "BOTTOM") +
      ", xPos=" + std::to_string(m_xPos) +
      ", yPos=" + std::to_string(m_yPos) +
      ", pagenum=" + std::to_string(m_pagenum) +
      ", szPath=" + m_szPath;
}